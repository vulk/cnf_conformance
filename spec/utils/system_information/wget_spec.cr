# require "../../spec_helper"
# require "colorize"
# require "../../../src/tasks/utils/utils.cr"
# require "../../../src/tasks/prereqs.cr"
# require "../../../src/tasks/utils/system_information/wget.cr"
# require "file_utils"
# require "sam"

# describe "Wget" do

#   it "'wget_global_response()' should return the information about the wget installation", tags: ["wget"]  do
#     (wget_global_response(true)).should contain("GNU Wget")
#   end

#   it "'wget_local_response()' should return the information about the wget installation", tags: ["wget"]  do
#     (wget_local_response(true)).should eq("")
#   end

#   it "'wget_version()' should return the information about the wget version", tags: ["wget"]  do
#     (wget_version(wget_global_response)).should match(/(([0-9]{1,3}[\.]){1,2}[0-9]{1,3})/)
#     (wget_version(wget_local_response)).should contain("")
#   end

#   it "'wget_installations()' should return the information about the wget installation", tags: ["wget"]  do
#     (wget_installation(true)).should contain("wget found")
#   end
# end
