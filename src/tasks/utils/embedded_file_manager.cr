require "totem"
require "colorize"
require "logger"
require "halite"

module EmbeddedFileManager
  macro cri_tools
    # CRI_TOOLS = File.read("./tools/cri-tools/manifest.yml")
    CRI_TOOLS = Base64.decode_string("{{ `cat ./tools/cri-tools/manifest.yml | base64` }}")
  end

  macro node_failure_values
    # NODE_FAILED_VALUES = File.read("./embedded_files/node_failure_values.yml")
    NODE_FAILED_VALUES = Base64.decode_string("{{ `cat ./embedded_files/node_failure_values.yml  | base64` }}")
  end

  macro reboot_daemon
    REBOOT_DAEMON = Base64.decode_string("{{ `cat ./tools/reboot_daemon/manifest.yml | base64` }}")
  end

  macro chaos_network_loss
    CHAOS_NETWORK_LOSS = Base64.decode_string("{{ `cat ./embedded_files/chaos_network_loss.yml  | base64` }}")
  end

  macro chaos_cpu_hog
    CHAOS_CPU_HOG = Base64.decode_string("{{ `cat ./embedded_files/chaos_cpu_hog.yml  | base64` }}")
  end

  macro chaos_container_kill
    CHAOS_CONTAINER_KILL = Base64.decode_string("{{ `cat ./embedded_files/chaos_container_kill.yml  | base64` }}")
  end

  macro points_yml
    POINTSFILE = Base64.decode_string("{{ `cat ./embedded_files/points.yml  | base64` }}")
  end

  def self.points_yml_write_file
    File.write("points.yml", POINTSFILE)
  end
end
