# coding: utf-8
require "./find.cr"

# To avoid circular dependencies:
# airgap uses airgaputils
# airgap uses tar
# tar uses airgaputils
# airgaputils uses find
module AirGapUtils
  TAR_REPOSITORY_DIR = "/tmp/repositories"

  def self.image_pull_policy(file, output_file = "")
    input_content = File.read(file)
    output_content = input_content.gsub(/(.*imagePullPolicy:)(.*)/, "\\1 Never")

    # LOGGING.debug "pull policy found?: #{input_content =~ /(.*imagePullPolicy:)(.*)/}"
    # LOGGING.debug "output_content: #{output_content}"
    if output_file.empty?
      input_content = File.write(file, output_content)
    else
      input_content = File.write(output_file, output_content)
    end
    #
    # TODO find out why this doesn't work
    # LOGGING.debug "after conversion: #{File.read(file)}"
  end

  def self.tar_name_by_helm_chart(config_src : String)
    FileUtils.mkdir_p(TAR_REPOSITORY_DIR)
    LOGGING.debug "tar_name_by_helm_chart ls /tmp/repositories:" + `ls -al /tmp/repositories`
    tar_dir = helm_tar_dir(config_src)
    tgz_files = Find.find(tar_dir, "*.tgz*")
    tar_files = Find.find(tar_dir, "*.tar*") + tgz_files
    tar_name = ""
    tar_name = tar_files[0] if !tar_files.empty?
    LOGGING.info "tar_name: #{tar_name}"
    tar_name
  end

  def self.tar_info_by_config_src(config_src : String)
    FileUtils.mkdir_p(TAR_REPOSITORY_DIR)
    LOGGING.debug "tar_info_by_config_src ls /tmp/repositories:" + `ls -al /tmp/repositories`
    # chaos-mesh/chaos-mesh --version 0.5.1
    repo = config_src.split(" ")[0]
    repo_dir = repo.gsub("/", "_")
    chart_name = repo.split("/")[-1]
    repo_path = "repositories/#{repo_dir}"
    tar_dir = "/tmp/#{repo_path}"
    tar_info = {repo: repo, repo_dir: repo_dir, chart_name: chart_name,
                repo_path: repo_path, tar_dir: tar_dir, tar_name: tar_name_by_helm_chart(config_src)}
    LOGGING.info "tar_info: #{tar_info}"
    tar_info
  end

  def self.helm_tar_dir(config_src : String)
    FileUtils.mkdir_p(TAR_REPOSITORY_DIR)
    LOGGING.debug "helm_tar_dir ls /tmp/repositories:" + `ls -al /tmp/repositories`
    # chaos-mesh/chaos-mesh --version 0.5.1
    repo = config_src.split(" ")[0]
    repo_dir = repo.gsub("/", "_")
    chart_name = repo.split("/")[-1]
    repo_path = "repositories/#{repo_dir}"
    tar_dir = "/tmp/#{repo_path}"
    LOGGING.info "helm_tar_dir: #{tar_dir}"
    tar_dir
  end
end
