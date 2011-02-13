module Jasmine
  class Config
    require 'yaml'
    require 'erb'

    @@specs       = []
    @@sources     = []
    @@helpers     = []
    @@stylesheets = []
    @@mappings    = {}

    class << self
      def map_files(path, patterns)
        dir = File.expand_path(path)
        match_files(dir, patterns).map{|file| File.join(mapping_for(dir), file)}
      end

      def mapping_for(dir)
        mapping = @@mappings[dir]
        mapping ||= @@mappings[dir] = '/' if dir == src_dir
        mapping ||= @@mappings[dir] = new_mapping
        mapping
      end

      def new_mapping
        "/__#{rand(10**30).to_s(36)}__"
      end

      def match_files(dir, patterns)
        negative, positive = patterns.partition {|pattern| /^!/ =~ pattern}
        chosen, negated = [positive, negative].collect do |patterns|
          patterns.collect do |pattern|
            matches = Dir.glob(File.join(dir, pattern.gsub(/^!/,'')))
            matches.collect {|f| f.sub("#{dir}/", "")}.sort
          end.flatten.uniq
        end
        chosen - negated
      end

      def simple_config
        File.exist?(simple_config_file) ? YAML::load(ERB.new(File.read(simple_config_file)).result(binding)) || {} : {}
      end

      def project_root
        Dir.pwd
      end

      def simple_config_file
        File.join(project_root, 'spec/javascripts/support/jasmine.yml')
      end      

      def src_dir
        File.join(*[project_root, simple_config['src_dir']].compact)
      end

      def spec_dir
        File.join(project_root, simple_config['spec_dir'] || 'spec/javascripts')
      end

      def mappings
        @@mappings
      end

      def create
        add_helpers      spec_dir, simple_config['helpers']     || ["helpers/**/*.js"]
        add_specs        spec_dir, simple_config['spec_files']  || ["**/*[sS]pec.js"]
        add_stylesheets  src_dir,  simple_config['stylesheets']
        add_sources      src_dir,  simple_config['src_files']
        new
      end
    end

    %w{ helpers specs sources stylesheets }.each do |file_type|
      class_eval <<-EOF
        def self.add_#{file_type}(path, patterns)
          return if patterns.nil?
          @@#{file_type}.concat map_files(path, patterns)
        end

        def #{file_type}
          @@#{file_type}
        end
      EOF
    end
    
    def spec_dir
      self.class.spec_dir
    end

    def src_dir
      self.class.src_dir
    end

    def mappings
      @@mappings
    end

    def browser
      ENV["JASMINE_BROWSER"] || 'firefox'
    end

    def jasmine_host
      ENV["JASMINE_HOST"] || 'http://localhost'
    end

    def external_selenium_server_port
      ENV['SELENIUM_SERVER_PORT'] && ENV['SELENIUM_SERVER_PORT'].to_i > 0 ? ENV['SELENIUM_SERVER_PORT'].to_i : nil
    end

    def start_server(port = 8888)
      server = Rack::Server.new(:Port => port, :AccessLog => [])
      server.instance_variable_set(:@app, Jasmine.app(self)) # workaround for Rack bug, when Rack > 1.2.1 is released Rack::Server.start(:app => Jasmine.app(self)) will work
      server.start
    end

    def start
      start_servers
      @client = Jasmine::SeleniumDriver.new("localhost", @selenium_server_port, "*#{browser}", "#{jasmine_host}:#{@jasmine_server_port}/")
      @client.connect
    end

    def stop
      @client.disconnect
    end

    def start_jasmine_server
      @jasmine_server_port = Jasmine::find_unused_port
      Thread.new do
        start_server(@jasmine_server_port)
      end
      Jasmine::wait_for_listener(@jasmine_server_port, "jasmine server")
      puts "jasmine server started."
    end

    def windows?
      require 'rbconfig'
      ::RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
    end

    def start_selenium_server
      @selenium_server_port = external_selenium_server_port
      if @selenium_server_port.nil?
        @selenium_server_port = Jasmine::find_unused_port
        require 'selenium-rc'
        ::SeleniumRC::Server.boot("localhost", @selenium_server_port, :args => [windows? ? ">NUL" : "> /dev/null"])
      else
        Jasmine::wait_for_listener(@selenium_server_port, "selenium server")
      end
    end

    def start_servers
      start_jasmine_server
      start_selenium_server
    end

    def run
      begin
        start
        puts "servers are listening on their ports -- running the test script..."
        tests_passed = @client.run
      ensure
        stop
      end
      return tests_passed
    end

    def eval_js(script)
      @client.eval_js(script)
    end

    def json_generate(obj)
      @client.json_generate(obj)
    end

    def js_files(spec_filter = nil)
      spec_files_to_include = spec_filter.nil? ? specs : self.class.map_files(spec_dir, [spec_filter])
      sources | helpers | spec_files_to_include
    end

    def specs_full_paths
      specs.map{|file| file.gsub(@@mappings[spec_dir], spec_dir)}
    end
  end
end