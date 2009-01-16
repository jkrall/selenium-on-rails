require 'yaml'

class SeleniumOnRailsConfig
  @@defaults = {:environments => ['test']}
  def self.get var, default = nil
    value = configs[var.to_s]
    value = @@defaults[var] if value.nil?
    value = default if value.nil?
    value = yield if block_given? and value.nil?
    value
  end

  private
    def self.configs
      unless defined? @@configs
        file = File.expand_path(RAILS_ROOT + '/config/selenium.yml')        
        if not File.exist?(file)
          file = File.expand_path(File.dirname(__FILE__) + '/../config.yml')
        end
        @@configs = File.exist?(file) ? YAML.load_file(file) : {}
      end
      @@configs
    end

end
