require "../../spec_helper"
require "colorize"
require "../../../src/tasks/utils/utils.cr"
require "../../../src/tasks/prereqs.cr"
require "../../../src/tasks/utils/system_information/helm.cr"
require "file_utils"
require "sam"

describe "Helm" do
  it "'helm_global_response()' should return the information about the helm installation", tags: ["helm-utils"] do
    # TODO make global response be a regex of v. or nil?
    # (helm_global_response(true)).should contain("\"v2.")
  end

  it "'helm_local_response()' should return the information about the helm installation", tags: ["helm-utils"] do
    (helm_local_response(true)).should contain("\"v3.")
  end

  it "'helm_version()' should return the information about the helm version", tags: ["helm-utils"] do
    (helm_version(helm_local_response)).should contain("v3.")
  end

  it "'helm_installations()' should return the information about the helm installation", tags: ["helm-utils"] do
    (helm_installation(true)).should contain("helm found")
  end

  it "'Helm.helm_gives_k8s_warning?' should pass when k8s config = chmod 700", tags: ["helm-utils"] do
    (Helm.helm_gives_k8s_warning?(true)).should be_false
  end
end
