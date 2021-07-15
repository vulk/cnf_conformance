require "totem"
require "colorize"
# todo remove dependency
require "./cnf_manager.cr"
require "halite"

# todo put in a separate library. it shold go under ./tools for now
module DockerClient
  def self.pull(image)
    LOGGING.info "Docker.pull command: #{image}"
    status = Process.run("docker pull #{image}",
      shell: true,
      output: output = IO::Memory.new,
      error: stderr = IO::Memory.new)
    LOGGING.info "Docker.pull output: #{output.to_s}"
    LOGGING.info "Docker.pull stderr: #{stderr.to_s}"
    {status: status, output: output, error: stderr}
  end

  def self.save(image, output_file)
    LOGGING.info "Docker.save command: docker save #{image} -o #{output_file}"
    status = Process.run("docker save #{image} -o #{output_file}",
      shell: true,
      output: output = IO::Memory.new,
      error: stderr = IO::Memory.new)
    LOGGING.info "Docker.save output: #{output.to_s}"
    LOGGING.info "Docker.save stderr: #{stderr.to_s}"
    {status: status, output: output, error: stderr}
  end

  ##############################################
  # All docker images can have one, two, three, or more segments. The docker images that have
  # multiple segments are separated by a slash.
  #
  # ** Multiple segments **
  # (Fully qualified) registry name with optional port /Org/image combination
  # Multiple segment examples: e.g. docker.io/coredns/coredns
  # mydockerregistry.io:8080/coredns/coredns, mydockerregistry.io:8080/coredns/coredns:latest,
  # mydockerregistry.io:8080/privatecordnsorg/coredns/coredns:latest
  #
  # Two segment examples: coredns/coredns,
  # 	docker.io/busybox,
  # 	myhostname:5000/myimagename:mytag
  #
  #	1) If the first segment has a period . in it, then the segment is a
  # fully qualified domain name.
  #
  #	2) If the first segment has colon in it : everything after the colon
  # is a port number
  #  a) If there are three or more segments, all segments (the middle
  # segments) from the first and before the last are org names
  #
  # 3) If the first segment is not a fully qualified domain name
  #  a) if there are two elements, the first element is an org
  #  b) If there are three or more segments, all segments excluding
  #  the last are org names
  #
  # ** The last segment (or one segment) **
  # Official docker image string
  # e.g. busybox
  #
  # 4.a) If the docker image is only one segment,docker.io is used for the
  # registry, the whole segment is used image name, and if there is no
  # tag, `latest` is used as the tag
  #
  # 4.b) Everything in the one segment (or the last segment if there are
  # multiple segments) is an image or image:tag combination.
  # ```
  # DockerClient.parse_image("mydockerregistry.io:8080/coredns/coredns:latest")
  # # => {"org_image" => "coredns/corends:latest", "org" => "coredns",
  # # "image" => "coredns:latest", "registry" => "mydockerregistry.io:8080", "tag" => "latest"}
  # ```
  def self.parse_image(fqdn_image_text)
    resp = {"registry"      => "",
            "org_image"     => "",
            "org"           => "",
            "image_and_tag" => "",
            "image_name"    => "",
            "tag"           => ""}
    size = fqdn_image_text.split("/").size
    first_segment = fqdn_image_text.split("/")[0]
    last_segment = fqdn_image_text.split("/")[-1]

    #	1) If the first segment has a period . in it, then the segment is a
    # fully qualified domain name.
    #	2) If the first segment has colon in it : everything after the colon
    # is a port number
    if (first_segment =~ /\./ || first_segment =~ /:/)
      resp["registry"] = first_segment
      #  a) If there are three or more segments, all segments (the middle
      # segments) from the first and before the last are org names
      if size > 2
        resp["org"] = fqdn_image_text.split("/")[1..-2]
      elsif size = 2
        resp["org"] = first_segment
      else
        LOGGING.error "size of image text should never = 1 or nil: #{fqdn_image_text}"
      end
    else # first segment not a registry
      resp["registry"] = ""
      if size = 1
        resp["org"] = ""
        # 3) If the first segment is not a fully qualified domain name
        #  a) if there are two segments, the first segment is an org
      elsif size = 2
        resp["org"] = first_segment
        #  b) If there are three or more segments, all segments (the middle
        # segments) after the first and before the last are org names
      elsif size > 2
        resp["org"] = fqdn_image_text.split("/")[0..-2]
      end
    end
    resp["org_image"] = "#{resp["org"].empty? ? "" : resp["org"] + "/"}#{last_segment}"
    # 4.a) If there is only one segment, docker.io is used for the
    # registry.  If there is no : in the image text, `latest` is used as the tag
    # 4.b) Everything in the one segment (or the last segment if there are
    # multiple segments) is an image or image:tag combination.
    resp["image_and_tag"] = last_segment
    if size == 1
      resp["registry"] = "docker.io"
    end
    resp["image_name"] = last_segment.image.split(":")[0]?
    if last_segment.image.split(":")[1]?
      resp["tag"] = last_segment.image.split(":")[1]?
    else
      resp["tag"] = "latest"
    end
    LOGGING.info "org/image:tag : #{resp}"
    resp
  end

  module Get
    # TODO remove if not used
    def self.image_tags(image_name) : Halite::Response
      LOGGING.info "tags image name: #{image_name}"
      # if image doesn't have a / in it, it has no user and is an official docker reposistory
      # these are prefixed with library/
      # if there are three elements in the array, use the last two elements as the org/image:tag combo
      # if there are two elements in the array, use both elements as the image/tag combo
      if image_name.split("/").size > 2
        image_name = "#{image_name.split("/")[1]}/#{image_name.split("/")[2]}"
      end
      LOGGING.info "org/image:tag : #{image_name}"
      modified_image_with_repo = ((image_name =~ /\//) == nil) ? "library/" + image_name : image_name

      # TODO make this work with a local registry, if used in the future
      LOGGING.info "docker halite url: #{"https://hub.docker.com/v2/repositories/#{modified_image_with_repo}/tags/?page_size=100"}"
      docker_resp = Halite.get("https://hub.docker.com/v2/repositories/#{modified_image_with_repo}/tags/?page_size=100", headers: {"Authorization" => "JWT"})
      LOGGING.debug "docker image resp: #{docker_resp}"
      docker_resp
    end

    def self.image_by_tag(docker_image_list, tag)
      # if image_tag = nil then get latest tag
      modified_tag = tag == nil ? "latest" : tag
      latest_image = docker_image_list.parse("json")["results"].as_a.find { |x| x["name"] == "#{modified_tag}" }
      LOGGING.debug "docker parse resp: #{latest_image}"
      (LOGGING.error "no image found for tag: #{modified_tag}") if latest_image == nil
      latest_image
    end
  end
end
