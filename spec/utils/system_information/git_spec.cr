require "../../spec_helper"
require "colorize"
require "../../../src/tasks/utils/utils.cr"
require "../../../src/tasks/prereqs.cr"
require "../../../src/tasks/utils/system_information/git.cr"
require "file_utils"
require "sam"

describe "Git" do
  it "'git_global_response()' should return the information about the git installation", tags: ["git-prereq"] do
    (git_global_response(true)).should contain("git version")
  end

  it "'git_local_response()' should return the information about the git installation", tags: ["git-prereq"] do
    (git_local_response(true)).should eq("")
  end

  it "'git_version()' should return the information about the git version", tags: ["git-prereq"] do
    (git_version(git_global_response)).should match(/(([0-9]{1,3}[\.]){1,2}[0-9]{1,3})/)
    (git_version(git_local_response)).should contain("")
  end

  it "'git_installations()' should return the information about the git installation", tags: ["git-prereq"] do
    (git_installation(true)).should contain("git found")
  end
end
