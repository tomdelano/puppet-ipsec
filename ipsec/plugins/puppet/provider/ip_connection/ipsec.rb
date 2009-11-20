#########################################################################
#
#   Copyright 2008 Bob the Builder, bobthebuilder@constructionsite.com 
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

# Puppet Provider for IPSec-Tools on SLES
#
#
Puppet::Type.type(:ip_connection).provide(:ipsec) do 
    desc "Provider for IPSec-Tools.  
      http://www.ipsec-howto.org/x304.html"

    confine :operatingsystem => ["SLES"] # this provider may be valid for other operating systems too, but was not tested on others than SLES

    $setkeyconf = "/etc/racoon/setkey.conf"
    $setkeyconftmp = $setkeyconf + ".tmp"
    $nonIPSecPorts = Array[ "8140" ]
    $ipsecpolicy = "ipsec esp/transport//require ah/transport//require"
    $nonipsecpolicy = "none"

    def exists?
        info("")
        info("IPSEC: Call 'exists?' for #{resource[:alias]}: #{resource[:sourceip]} -> #{resource[:destip]} on port '#{resource[:port]}'.")
        # filter entries with sourceip == destip
        if resource[:sourceip] == resource[:destip] 
            info("Skip this entry as sourceip ('#{resource[:sourceip]}') and destip ('#{resource[:destip]}') are equal.")
            # return what it wants to hear
            if resource[:ensure] == :present
                return true
            else
                return false
            end
        end
        # check if the entries for this ip_connection exist.
        searchEntry = getEntryForSearch(resource[:sourceip], resource[:destip], resource[:port], $ipsecpolicy, resource[:servicetype])
        result = existsEntry(searchEntry)
        # if the status of the resource is already ok we have to anyway update the NonIPSecEntries
        if ((result && resource[:ensure] == :present) || (!result && resource[:ensure] != :present))
            updateNonIPSecEntries(resource[:sourceip], resource[:destip])
            reloadIPSecTools(false)
        end
        info("IPSEC: result: #{result}")
        return result
    end

    def create
        info("IPSEC: Create ipsec entries for #{resource[:alias]}: #{resource[:sourceip]} -> #{resource[:destip]} on port #{resource[:port]}.")
        # insert the 2 entries for this resource
        lines = createEntry(resource[:sourceip], resource[:destip], resource[:port], $ipsecpolicy, resource[:servicetype])
        debug("The lines to insert: #{lines}")
        debug("the file to insert into: '#{$setkeyconf}'")
        if File.file?($setkeyconf)
            file = nil
            result = "fail"
            begin
                file = File.open($setkeyconf, "a+")
                file.puts(lines)
                result = "success"                   
            rescue Exception => e
                err(e.message)
                err(e.backtrace.inspect)
                raise e
            ensure
                if file != nil
                    file.close()
                end    
                info("IPSEC: result: #{result}")
            end
            updateNonIPSecEntries(resource[:sourceip], resource[:destip])
            reloadIPSecTools(false)
        else
            raise "File '#{$setkeyconf}' does not exist! Can not add the entries for this connection."
        end
    end

    def destroy
        # remove the entries for this connection
        info("IPSEC: called destroy for #{resource[:alias]}: #{resource[:sourceip]} -> #{resource[:destip]} on port #{resource[:port]}, servicetype: '#{resource[:servicetype]}'")
        if resource[:sourceip] == resource[:destip]
            info("Skip this entry as sourceip ('#{resource[:sourceip]}') and destip ('#{resource[:destip]}') are equal.")
        else 
            removeEntries(resource[:sourceip], resource[:destip], resource[:port], resource[:servicetype])
            updateNonIPSecEntries(resource[:sourceip], resource[:destip])
            removeConsecEmptyLines($setkeyconf)
            reloadIPSecTools(true)
        end
        info("IPSEC: done")
    end 

    def reloadIPSecTools (flush)
        debug("IPSEC: changed #{$setkeyconf}, resetup setkey policy database with new file and reload racoon...")
        if flush
            output = `setkey -FP`
        end
        debug("IPSEC: Reload setkey.conf.")
        output = `setkey -f #{$setkeyconf}`
        debug("IPSEC: Reload racoon:")
        output = `/etc/init.d/racoon reload`
        debug(output)
        debug("IPSEC: done.")
    end

    def createEntry(sourceip, destip, port, policy, servicetype) 
        typestr = ""
        if servicetype != ""
            typestr = " # type: '#{servicetype}'"
        end
        result = "
spdadd #{sourceip}[0] #{destip}[#{port}] any -P out #{policy};#{typestr}
spdadd #{destip}[#{port}] #{sourceip}[0] any -P in #{policy};#{typestr}"
        if port != "any" && port != "0"
            result += "
spdadd #{sourceip}[#{port}] #{destip}[0] any -P out #{policy};#{typestr}
spdadd #{destip}[0] #{sourceip}[#{port}] any -P in #{policy};#{typestr}"
        end
        result += "\n"
        return result
    end

    def existsEntry(entry)
        debug("Calling 'existsEntry' for '#{entry}'.")
        if not File.file?($setkeyconf)
            debug("IPSEC: provider detected missing #{$setkeyconf} file!")
            file = File.new($setkeyconf, "w")
            file.close
            if not File.file?($setkeyconf)
                err("IPSEC: provider could not create #{$setkeyconf}!")
            end
        end
        file = nil
        result = false
        begin
            file = File.open($setkeyconf, "r")
            file.each {|line|
                if line.index(entry) != nil
                    result = "true"
                    return true
                end
            }
            result = false  
        rescue Exception => e
            err(e.message)
            err(e.backtrace.inspect)
            raise e
        ensure
            if file != nil
                file.close()
            end
            debug("IPSEC: result: #{result}")
        end 
        return false
    end
    
    def getEntryForSearch(sourceip, destip, port, policy, servicetype)
        typestr = ""
        if servicetype != ""
            typestr = " # type: '#{servicetype}'"
        end
        return "spdadd #{sourceip}[0] #{destip}[#{port}] any -P out #{policy};#{typestr}" 
    end

    def removeEntries(sourceip, destip, port, servicetype)
        debug("IPSEC: removeEntries matching: ip1 '#{sourceip}', ip2 '#{destip}', port '#{port}' and servicetype '#{servicetype}'")
        if File.file?($setkeyconf)
            begin
                file = File.open($setkeyconf, "r")
                tmpfile = File.new($setkeyconftmp, "w+")
                file.each { |line|
                    if !((line =~ /#{sourceip}/) && (line =~ /#{destip}/) && (line =~ /#{port}.*#{servicetype}/))
                        tmpfile.puts(line)
                    else
                        debug("found matching line: '#{line.chomp()}'")
                    end
                }
                file.close()
                tmpfile.close()
                File.delete($setkeyconf)
                File.rename($setkeyconftmp, $setkeyconf)
            rescue Exception => e
                err(e.message)
                err(e.backtrace.inspect)
                raise e
            ensure
                if file != nil && !file.closed?
                    file.close()
                end
                if tmpfile != nil && !tmpfile.closed?
                    tmpfile.close()
                end
            end
        else
            raise "File '#{$setkeyconf}' does not exist! Can not add the entries for this connection."
        end
        debug("IPSEC: done.")
    end
   
    def removeObsoleteNonIPSecEntries(sourceip, destip, entryfound)
        debug("IPSEC: remove obsolete non-ipsec entries.")
        # check if the non IPSec entries are still needed: are there any policies for this connection left?
        if File.file?($setkeyconf)
            begin
                if entryfound
                    debug("IPSEC: entries found, remove only the obsolet IPSec exceptions:")
                else
                    debug("IPSEC: no entries found, remove all the non IPSec exceptions:")
                end
                file = File.open($setkeyconf, "r")
                tmpfile = File.new($setkeyconftmp, "w+")
                file.each { |line|
                    if !((line =~ /#{sourceip}/) && (line =~ /#{destip}/))
                        tmpfile.puts(line)
                    elsif entryfound # if we found entries we check the existing exceptions and keep the configured ones
                        keepentry = false
                        if line =~ / #{$nonipsecpolicy};/
                            $nonIPSecPorts.each { |port|
                                if ((line =~ /\[#{port}\]/))
                                    keepentry = true
                                    break
                                end
                            }
                        else
                            keepentry = true
                        end
                        if keepentry
                            tmpfile.puts(line)
                        else
                            debug("removing line: '#{line.chomp()}'")
                        end
                    else 
                        debug("removing line: '#{line.chomp()}'")
                    end
                }
                file.close()
                tmpfile.close()
                File.delete($setkeyconf)
                File.rename($setkeyconftmp, $setkeyconf)
            rescue Exception => e
                err(e.message)
                err(e.backtrace.inspect)
                raise e
            ensure
                if file != nil && !file.closed?
                    file.close()
                end
                if tmpfile != nil && !tmpfile.closed?
                    tmpfile.close()
                end
                debug("IPSEC: removeObsoleteNonIPSecEntries done.")
            end
        else
            raise "File '#{$setkeyconf}' does not exist! Can not add the entries for this connection."
        end
        debug("IPSEC: done.")
    end

    def addMissingNonIPSecEntries(sourceip, destip)
        debug("IPSEC: add missing non-ipsec entries.")
        if File.file?($setkeyconf)
            # check if Entry exists
            lines = ""
            $nonIPSecPorts.each { |port|
                searchEntry = getEntryForSearch(sourceip, destip, port, $nonipsecpolicy, "")
                if not existsEntry(searchEntry)
                    lines += createEntry(sourceip, destip, port, $nonipsecpolicy, "")
                end
            }
            debug("The lines to insert: '#{lines}'")
            tmpfile = File.open($setkeyconftmp, "w+")
            tmpfile.puts("spdflush;")
            tmpfile.puts(lines)
            file = File.open($setkeyconf, "r")
            file.each { |line|
                if !(line =~ /flush/) # get rid of flush operations further down in the file..
                    tmpfile.puts(line)
                end
            }
            file.close()
            tmpfile.close()
            File.delete($setkeyconf)
            File.rename($setkeyconftmp, $setkeyconf)
        else
            raise "File '#{$setkeyconf}' does not exist! Can not add the entries for this connection."
        end
        debug("IPSEC: addMissingNonIPSecEntries done.")
    end

    def updateNonIPSecEntries(sourceip, destip)
        debug("IPSEC: update non-ipsec entries.")
        if File.file?($setkeyconf)
            debug("IPSEC: checking for entries containing the two IPs: '#{sourceip}', '#{destip}'")
            file = File.open($setkeyconf, "r")
            entryfound = false
            file.each { |line|
                if (line =~ /#{sourceip}/) && (line =~ /#{destip}/) && !(line =~ /#{$nonipsecpolicy};/) # find ipsec entries of this ip combination
                    entryfound = true
                    break
                end
            }
            removeObsoleteNonIPSecEntries(sourceip, destip, entryfound)
            if entryfound
                addMissingNonIPSecEntries(sourceip, destip)
            end
        else
            raise "File '#{$setkeyconf}' does not exist! Can not add the entries for this connection."
        end
        debug("IPSEC: updateNonIPSecEntries  done.")
    end

    def removeConsecEmptyLines(filename)
        if File.file?(filename)
            begin
                cleanedfilename = filename + ".cleaned"
                file = File.open(filename, "r")
                tmpfile = File.new(cleanedfilename, "w+")
                emptylines = 0
                file.each { |line|
                    if line.chomp().empty?
                        emptylines += 1
                    else
                        emptylines = 0
                    end
                    if emptylines < 2
                        tmpfile.puts(line)
                    end
                }
                file.close()
                tmpfile.close()
                File.delete(filename)
                File.rename(cleanedfilename, filename)
            rescue Exception => e
                err(e.message)
                err(e.backtrace.inspect)
                # swallow
            ensure
                 if file != nil && !file.closed?
                    file.close()
                end
                if tmpfile != nil && !tmpfile.closed?
                    tmpfile.close()
                end
            end
        else
            raise "File '#{$setkeyconf}' does not exist! Can not add the entries for this connection."
        end
    end

end
