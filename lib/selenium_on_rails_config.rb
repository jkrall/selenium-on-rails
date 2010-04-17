require 'yaml'
require 'erb'

class SeleniumOnRailsConfig
  @@defaults = {:environments => ['test', 'selenium']}
  def self.get var, default = nil
    value = configs[var.to_s]
    value = @@defaults[var] if value.nil?
    value = default if value.nil?
    value = yield if block_given? and value.nil?
    value
  end

  private
    def self.configs
      @@configs ||= nil
      unless @@configs
        files = [File.join(RAILS_ROOT, 'config', 'selenium.yml'), File.expand_path(File.dirname(__FILE__) + '/../config.yml')]
        files.each do |file|
          if File.exist?(file)
            @@configs = YAML.load(ERB.new(IO.read(file)).result)
            break
          end
        end
        @@configs ||= {}
      end
      @@configs
    end

end
