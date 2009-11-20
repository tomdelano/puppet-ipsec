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

# Puppet Type: ip_connection 
#
#
Puppet::Type.newtype(:ip_connection) do

    @doc = "An IP connection between two nodes."

    ensurable

    newparam(:name) do
    end

    newparam(:servicetype) do
        # validation missing
        desc "The type of the service e.g. ldap."
    end

    newparam(:sourceip) do
        # validation missing
        desc "The source IP."
    end

    newparam(:destip) do
       # validation missing
        desc "The destination IP."
    end

	newparam(:port) do
		# validation missing
		desc "The port of the connection"
	end

end
