require "../spec_helper"
require "colorize"
require "../../src/tasks/utils/utils.cr"
require "../../src/tasks/utils/airgap.cr"
require "file_utils"
require "sam"

describe "BootstrapK8s" do
  unless Dir.exists?("./tmp")
    LOGGING.info `mkdir ./tmp`
  end


  #TODO setup for publish_tarball
  #TODO ./bootstrap-cri-tools.sh registry conformance/cri-tools:latest 
  # previous line gets the 'cri-tools' image by building it from ./cri-tools/Dockerfile then it tags it wit the name conformance/cri-tools:latest
  #TODO use testimage.tar in fixtures as parameter
    
  # it "'pods_with_tar' should return all pods with the tar binary available", tags: ["airgap"] do
  #   AirGap.pods_with_tar
  # end

   
#  it "'publish_tarball' should publish a tarball", tags: ["airgap"] do

#   AirGap.publish_tarball(tarball_name)
#   (File.exists?("./tmp/airgapped.tar.gz")).should be_true
#  ensure
#    `rm ./tmp/airgapped.tar.gz`
#  end

end


