module TacticSolver
  class Config
    def initialize
      config_file = "config.yml"
      raise "Missing configuration file" unless File.exist? config_file
      @config = YAML::load(File.open(config_file))
    end

    def method_missing param
      value = @config["#{param}"]
      raise "ERROR: '#{param}' is not defined in the configuration file" unless value
      value
    end
  end
end
