require "easybup/version"

require 'attr-chain'
require 'pathname'

module Easybup

    INIT_CFG_FILE = <<__DATA__
default "task0"

source "sample_source" do
    path "/path/to/your/source_file"
end

repo "sample_root" do
    bup_root "/path/to/your/bup_root"
end

task "task0" do
    source "sample_source"
    repo "sample_root"
end
__DATA__

    class Source
        include AttributeChain
        attr_chain :path, :index_file, :branch

        attr_reader :name

        def initialize(name)
            @name = name
        end

        def no_check_device
            @no_check_device = true
        end

        def verbose
            @verbose = true
        end

        def run_before

        end

        def exlucde

        end

        def exclude_from

        end

        def exclude_rx

        end
    end

    class Repo
        include AttributeChain
        attr_chain :bup_root
        attr_reader :name

        def initialize(name)
            @name = name
        end
    end

    class Task
        include AttributeChain
        attr_chain :source, :repo
        attr_reader :name

        def initialize(name)
            @name = name
        end
    end

    class Config
        include AttributeChain
        attr_chain :default
        attr_reader :sources, :repos, :tasks

        def initialize
            @sources = {}
            @repos = {}
            @tasks = {}
        end

        def self.parse(config)
            filename = "INIT_CFG_FILE"
            cfg = Config.new
            if config.is_a?(Pathname)
                filename = config.to_s
                config = Pathname.read
            end

            cfg.instance_eval(config, filename)
            cfg
        end

        def create_and_exec( maps, name, type, blk )
            inst = ( maps[ name.to_sym ] ||= type.new( name.to_sym ) )
            if blk
                inst.instance_eval(&blk)
            end
            inst
        end

        def source( name, &blk )
            create_and_exec( @sources, name, Source, blk )
        end

        def repo( name, &blk )
            create_and_exec( @repos, name, Repo, blk )
        end

        def task( name, &blk )
            create_and_exec( @tasks, name, Task, blk )
        end
    end
end
