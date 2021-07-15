require "../spec_helper"
require "../../src/tasks/utils/utils.cr"
require "../../src/tasks/utils/tar.cr"
require "../../src/tasks/utils/find.cr"
require "file_utils"
require "sam"

describe "TarClient" do
  before_all do
    unless Dir.exists?("./tmp")
      LOGGING.info `mkdir ./tmp`
    end
  end
  it "'.tar' should tar a source file or directory", tags: ["tar-install"] do
    `rm ./tmp/test.tar`
    TarClient.tar("./tmp/test.tar", "./spec/fixtures", "cnf-testsuite.yml")
    (File.exists?("./spec/fixtures/cnf-testsuite.yml")).should be_true
  ensure
    `rm ./tmp/test.tar`
  end

  it "'.untar' should untar a tar file into a directory", tags: ["tar-install"] do
    `rm ./tmp/test.tar`
    TarClient.tar("./tmp/test.tar", "./spec/fixtures", "cnf-testsuite.yml")
    TarClient.untar("./tmp/test.tar", "./tmp")
    (File.exists?("./tmp/cnf-testsuite.yml")).should be_true
  ensure
    `rm ./tmp/test.tar`
    `rm ./tmp/cnf-testsuite.yml`
  end

  it "'.modify_tar!' should untar file, yield to block, retar", tags: ["tar-install"] do
    `rm ./tmp/test.tar`
    input_content = File.read("./spec/fixtures/litmus-operator-v1.13.2.yaml")
    (input_content =~ /imagePullPolicy: Never/).should be_nil
    TarClient.tar("./tmp/test.tar", "./spec/fixtures", "litmus-operator-v1.13.2.yaml")
    TarClient.modify_tar!("./tmp/test.tar") do |directory|
      template_files = Find.find(directory, "*.yaml*", "100")
      LOGGING.debug "template_files: #{template_files}"
      template_files.map { |x| AirGapUtils.image_pull_policy(x) }
    end

    TarClient.untar("./tmp/test.tar", "./tmp")
    (File.exists?("./tmp/litmus-operator-v1.13.2.yaml")).should be_true
    input_content = File.read("./tmp/litmus-operator-v1.13.2.yaml")
    (input_content =~ /imagePullPolicy: Never/).should_not be_nil
  ensure
    `rm ./tmp/test.tar`
    `rm ./tmp/litmus-operator-v1.13.2.yaml`
  end
end
