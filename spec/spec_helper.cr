require "spec"
require "colorize"
require "../src/cnf_testsuite"

ENV["CRYSTAL_ENV"] = "TEST"

LOGGING.info "Building ./cnf-testsuite".colorize(:green)
`crystal build --warnings none src/cnf-testsuite.cr`
if $?.success?
  LOGGING.info "Build Success!".colorize(:green)
else
  LOGGING.info "crystal build failed!".colorize(:red)
  raise "crystal build failed in spec_helper"
end
