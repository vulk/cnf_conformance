require "totem"
require "colorize"
require "./types/cnf_testsuite_yml_type.cr"
require "./helm.cr"
require "uuid"
require "./points.cr"

module CNFManager
  module Task
    def self.task_runner(args, &block : Sam::Args, CNFManager::Config -> String | Colorize::Object(String) | Nil)
      LOGGING.info("task_runner args: #{args.inspect}")
      if check_cnf_config(args)
        single_task_runner(args, &block)
      else
        all_cnfs_task_runner(args, &block)
      end
    end

    # TODO give example for calling
    def self.all_cnfs_task_runner(args, &block : Sam::Args, CNFManager::Config -> String | Colorize::Object(String) | Nil)
      # Platforms tests dont have any cnfs
      if CNFManager.cnf_config_list(silent: true).size == 0
        single_task_runner(args, &block)
      else
        CNFManager.cnf_config_list(silent: true).map do |x|
          new_args = Sam::Args.new(args.named, args.raw)
          new_args.named["cnf-config"] = x
          single_task_runner(new_args, &block)
        end
      end
    end

    # TODO give example for calling
    def self.single_task_runner(args, &block : Sam::Args, CNFManager::Config -> String | Colorize::Object(String) | Nil)
      LOGGING.debug("single_task_runner args: #{args.inspect}")
      begin
        if args.named["cnf-config"]? # platform tests don't have a cnf-config
          config = CNFManager::Config.parse_config_yml(args.named["cnf-config"].as(String))
        else
          config = CNFManager::Config.new({destination_cnf_dir:        "",
                                           source_cnf_file:            "",
                                           source_cnf_dir:             "",
                                           yml_file_path:              "",
                                           install_method:             {:helm_chart, ""},
                                           manifest_directory:         "",
                                           helm_directory:             "",
                                           helm_chart_path:            "",
                                           manifest_file_path:         "",
                                           git_clone_url:              "",
                                           install_script:             "",
                                           release_name:               "",
                                           service_name:               "",
                                           docker_repository:          "",
                                           helm_repository:            {name: "", repo_url: ""},
                                           helm_chart:                 "",
                                           helm_chart_container_name:  "",
                                           rolling_update_tag:         "",
                                           container_names:            [{"name" => "", "rolling_update_test_tag" => ""}],
                                           white_list_container_names: [""]})
        end
        yield args, config
      rescue ex
        # Set exception key/value in results
        # file to -1
        update_yml("#{CNFManager::Points::Results.file}", "exit_code", "1")
        LOGGING.error ex.message
        ex.backtrace.each do |x|
          LOGGING.error x
        end
      end
    end
  end
end
