require File.expand_path(File.join(File.dirname(__FILE__), "spec_helper"))

describe Jasmine::Config do
  describe "configuration" do
    before :all do
      temp_dir_before
      Dir::chdir @tmp
      dir_name = "test_js_project"
      `mkdir -p #{dir_name}`
      Dir::chdir dir_name
      `#{@root}/bin/jasmine init .`
    end

    after :all do
      temp_dir_after
    end

    before :each do
      Jasmine::Config.stub!(:project_dir) { Dir.pwd }
      @template_dir = File.expand_path(File.join(@root, "generators/jasmine/templates"))      
    end

    after :each do
      Jasmine::Config.class_variable_set(:@@specs, [])
      Jasmine::Config.class_variable_set(:@@sources, [])
      Jasmine::Config.class_variable_set(:@@helpers, [])
      Jasmine::Config.class_variable_set(:@@stylesheets, [])
      Jasmine::Config.class_variable_set(:@@mappings, {})      
    end

    describe ".src_dir" do
      it "returns a path relative to project_root when src_dir set" do
        Jasmine::Config.stub!(:simple_config) { {'src_dir' => 'my/sources/are/here'} }
        Jasmine::Config.src_dir.should == File.join(Jasmine::Config.project_root, 'my', 'sources', 'are', 'here')
      end

      it "returns project_root when src_dir is not set" do
        Jasmine::Config.stub!(:simple_config) { {'src_dir' => nil} }
        Jasmine::Config.src_dir.should == Jasmine::Config.project_root
      end
    end

    describe ".simple_config_file" do
      it "returns the path to the default yaml config file" do
        Jasmine::Config.simple_config_file.should == File.join(Jasmine::Config.project_root, 'spec/javascripts/support/jasmine.yml')
      end
    end

    describe ".match_files" do
      before do
        Dir.stub!(:glob).and_return { |glob| [glob] }
      end

      it "returns the first appearance of duplicate filenames" do
        Jasmine::Config.match_files(Dir.pwd, ["file1.ext", "file2.ext", "file1.ext"]).should == ["file1.ext", "file2.ext"]
      end

      it "allows .gitignore style negation (!pattern)" do
        Jasmine::Config.match_files(Dir.pwd, ["file1.ext", "!file1.ext", "file2.ext"]).should == ["file2.ext"]
      end
    end

    describe ".map_files" do
      before do
        Jasmine::Config.stub!(:match_files) { ['file1.ext', 'file2.ext']}
      end

      it "maps the source directory to '/'" do
        routes = Jasmine::Config.map_files(Jasmine::Config.src_dir, ['*.ext'])
        routes.should == ['/file1.ext', '/file2.ext']
        Jasmine::Config.mappings[Jasmine::Config.src_dir].should == '/'
      end

      it "maps other paths to a unique path prefix" do
        arbitrary_path = "/any/path/will/do"
        routes  = Jasmine::Config.map_files(arbitrary_path, ['*.ext'])
        mapping = Jasmine::Config.mappings[arbitrary_path]
        mapping.should =~ /\/__\w{15,}__/
        routes.should == ["#{mapping}/file1.ext", "#{mapping}/file2.ext"]
      end

      it "maps different paths to different path prefixes" do
        one_path = "/any/path/will/do"
        two_path = "/any/other/path/too"
        Jasmine::Config.map_files(one_path, ['*.ext'])
        Jasmine::Config.map_files(two_path, ['*.ext'])
        Jasmine::Config.mappings[one_path].should_not == Jasmine::Config.mappings[two_path]
      end
    end

    describe ".simple_config" do
      describe "using default jasmine.yml" do
        before do
          Jasmine::Config.stub!(:new_mapping) { '/__spec__' }
        end

        it "configures file paths for the Jasmine runner" do
          config = Jasmine.configure!
          config.sources.should   =~ ['/public/javascripts/Player.js', '/public/javascripts/Song.js']
          config.stylesheets.should == []
          config.specs.should  == ['/__spec__/PlayerSpec.js']
          config.helpers.should     == ['/__spec__/helpers/SpecHelper.js']

          config.js_files.should    == [
            '/public/javascripts/Player.js',
            '/public/javascripts/Song.js',
            '/__spec__/helpers/SpecHelper.js',
            '/__spec__/PlayerSpec.js'
          ]

          config.js_files("PlayerSpec.js").should == [
            '/public/javascripts/Player.js',
            '/public/javascripts/Song.js',
            '/__spec__/helpers/SpecHelper.js',
            '/__spec__/PlayerSpec.js'
          ]

          config.specs_full_paths.should == [File.join(Jasmine::Config.project_root, 'spec/javascripts/PlayerSpec.js')]
        end
      end

#      it "should parse ERB" do
#        @config.stub!(:simple_config_file).and_return(File.expand_path(File.join(File.dirname(__FILE__), 'fixture/jasmine.erb.yml')))
#        Dir.stub!(:glob).and_return { |glob_string| [glob_string] }
#        @config.sources.should == ['file0.js', 'file1.js', 'file2.js',]
#      end

      describe "if jasmine.yml not found" do
        before do
          File.stub!(:exist?).and_return(false)
        end

        it "does not load any source files or stylesheet files" do
          config = Jasmine.configure!
          config.sources.should be_empty
          config.stylesheets.should be_empty
        end
      end

      describe "if jasmine.yml is empty" do
        before do
          YAML.stub!(:load).and_return(false)
        end

        it "does not load any source files or stylesheet files" do
          config = Jasmine.configure!
          config.sources.should be_empty
          config.stylesheets.should be_empty
        end
      end

      describe "customizing jasmine.yml" do
        it "returns configured stylesheets" do
          Jasmine::Config.stub(:simple_config).and_return({'stylesheets' => ['foo.css', 'bar.css']})
          Dir.stub!(:glob).and_return { |glob_string| [glob_string] }
          config = Jasmine.configure!
          config.stylesheets.should == ['/foo.css', '/bar.css']
        end
      end

      describe "using rails jasmine.yml" do
        before do
          Jasmine::Config.stub!(:new_mapping) { '/__spec__' }
          Jasmine::Config.stub!(:simple_config_file).and_return(File.join(@template_dir, 'spec/javascripts/support/jasmine-rails.yml'))          
        end

        it "loads rails related files" do
          ['public/javascripts/prototype.js',
           'public/javascripts/effects.js',
           'public/javascripts/controls.js',
           'public/javascripts/dragdrop.js',
           'public/javascripts/application.js'].each { |f| `touch #{f}` }

          config = Jasmine.configure!
          config.specs.should  == ['/__spec__/PlayerSpec.js']
          config.helpers.should     == ['/__spec__/helpers/SpecHelper.js']

          config.sources.should   == [
              '/public/javascripts/prototype.js',
              '/public/javascripts/effects.js',
              '/public/javascripts/controls.js',
              '/public/javascripts/dragdrop.js',
              '/public/javascripts/application.js',
              '/public/javascripts/Player.js',
              '/public/javascripts/Song.js'
          ]

          config.js_files.should == [
              '/public/javascripts/prototype.js',
              '/public/javascripts/effects.js',
              '/public/javascripts/controls.js',
              '/public/javascripts/dragdrop.js',
              '/public/javascripts/application.js',
              '/public/javascripts/Player.js',
              '/public/javascripts/Song.js',
              '/__spec__/helpers/SpecHelper.js',
              '/__spec__/PlayerSpec.js',
          ]

          config.js_files("PlayerSpec.js").should == [
              '/public/javascripts/prototype.js',
              '/public/javascripts/effects.js',
              '/public/javascripts/controls.js',
              '/public/javascripts/dragdrop.js',
              '/public/javascripts/application.js',
              '/public/javascripts/Player.js',
              '/public/javascripts/Song.js',
              '/__spec__/helpers/SpecHelper.js',
              '/__spec__/PlayerSpec.js'
          ]
        end
      end
    end

    describe "registering external libraries and stylesheets" do
      before do
        `touch #{@tmp}/third-party-file.js`
        `touch #{@tmp}/third-party-stylesheet.css`
      end

      describe ".add_helpers" do
        it "should include the 3rd party helpers before the jasmine.yml helpers" do
          Jasmine::Config.add_helpers(@tmp, ['third-party-*.js'])
          config = Jasmine.configure!
          config.helpers[0].should =~ %r{/__\w+__/third-party-file.js}
          config.helpers[1].should =~ %r{/__\w+__/helpers/SpecHelper.js}
        end
      end

      describe ".add_sources" do
        it "should include the 3rd party sources before the jasmine.yml sources" do
          Jasmine::Config.add_sources(@tmp, ['third-party-*.js'])
          config = Jasmine.configure!
          config.sources[0].should =~ %r{/__\w+__/third-party-file.js}
          config.sources[1].should == '/public/javascripts/Player.js'
        end
      end

      describe ".add_specs" do
        it "should include the 3rd party sources before the jasmine.yml sources" do
          Jasmine::Config.add_specs(@tmp, ['third-party-*.js'])
          config = Jasmine.configure!
          config.specs[0].should =~ %r{/__\w+__/third-party-file.js}
          config.specs[1].should =~ %r{/__\w+__/PlayerSpec.js}
        end
      end

      describe ".add_stylesheets" do
        it "should include 3rd party stylesheets" do
          Jasmine::Config.add_stylesheets(@tmp, ['*.css'])
          config = Jasmine.configure!
          config.stylesheets[0].should =~ %r{/__\w+__/third-party-stylesheet.css}
        end
      end
    end
  end

  describe "browser configuration" do
    it "should use firefox by default" do
      ENV.stub!(:[], "JASMINE_BROWSER").and_return(nil)
      config = Jasmine.configure!
      config.stub!(:start_servers)
      Jasmine::SeleniumDriver.should_receive(:new).
              with(anything(), anything(), "*firefox", anything()).
              and_return(mock(Jasmine::SeleniumDriver, :connect => true))
      config.start
    end

    it "should use ENV['JASMINE_BROWSER'] if set" do
      ENV.stub!(:[], "JASMINE_BROWSER").and_return("mosaic")
      config = Jasmine.configure!
      config.stub!(:start_servers)
      Jasmine::SeleniumDriver.should_receive(:new).
              with(anything(), anything(), "*mosaic", anything()).
              and_return(mock(Jasmine::SeleniumDriver, :connect => true))
      config.start
    end
  end

  describe "jasmine host" do
    it "should use http://localhost by default" do
      config = Jasmine.configure!
      config.instance_variable_set(:@jasmine_server_port, '1234')
      config.stub!(:start_servers)

      Jasmine::SeleniumDriver.should_receive(:new).
              with(anything(), anything(), anything(), "http://localhost:1234/").
              and_return(mock(Jasmine::SeleniumDriver, :connect => true))
      config.start
    end

    it "should use ENV['JASMINE_HOST'] if set" do
      ENV.stub!(:[], "JASMINE_HOST").and_return("http://some_host")
      config = Jasmine.configure!
      config.instance_variable_set(:@jasmine_server_port, '1234')
      config.stub!(:start_servers)

      Jasmine::SeleniumDriver.should_receive(:new).
              with(anything(), anything(), anything(), "http://some_host:1234/").
              and_return(mock(Jasmine::SeleniumDriver, :connect => true))
      config.start
    end
  end

  describe "#start_selenium_server" do
    it "should use an existing selenium server if SELENIUM_SERVER_PORT is set" do
      config = Jasmine.configure!
      ENV.stub!(:[], "SELENIUM_SERVER_PORT").and_return(1234)
      Jasmine.should_receive(:wait_for_listener).with(1234, "selenium server")
      config.start_selenium_server
    end
  end
end
