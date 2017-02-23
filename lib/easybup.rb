require "easybup/version"

require 'attr-chain'
require 'pathname'
require 'open3'
require 'byebug'

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

        attr_reader :name, :exclude_files

        def initialize(name)
            @name = name
            @exclude = []
            @bash = []
            @is_extenal_disk = false
            @exclude_files = []
        end

        def exists?
            if !@path.is_a? Array
                @path = [ @path ]
            end
            @path = @path.map{ |p| File.expand_path(p) }
            @path.all?{ |p| File.exists? p }
        end

        def external_disk?
            @is_extenal_disk
        end

        def external_disk
            @is_extenal_disk = true
        end

        def verbose
            @verbose = true
        end

        def exlucde(path=nil)
            if path.nil?
                @exclude
            else
                @exclude.push(path)
            end
        end

        def exclude_bash(bash=nil)
            if bash.nil?
                @bash
            else
                @bash.push(bash)
            end
        end

        def execute_bash
            @bash.each do |cmd|
                tmp_file = Tempfile.new( "easybup-exclude" )
                bash_cmd = "#{cmd} > #{tmp_file.path}"
                if !system(bash_cmd)
                    raise "bash command: `#{cmd}` execute error."
                end
                @exclude_files << tmp_file
            end
        end

        def run_bash(&blk)
            @bash.each do |cmd|
                thr = nil
                Open3.popen3( "/usr/bin/env", "bash", "-c", cmd ) do |stdin, stdout, stderr, wait_thr |
                    stdin.close

                    io_array = [ stdout, stderr ]

                    while !io_array.empty? do
                        ava_ios = IO.select( io_array )

                        ava_ios[0].each do |ava_io|
                            out_data = err_data = nil
                            if ava_io == stdout
                                begin
                                    out_data = ava_io.readpartial(102400) 
                                    if out_data == nil
                                        io_array.delete( stdout )
                                    end
                                rescue EOFError 
                                    io_array.delete( stdout )
                                end
                            elsif ava_io == stderr
                                begin
                                    err_data = ava_io.readpartial(102400) 
                                    if err_data == nil
                                        io_array.delete( stderr )
                                    end
                                    puts err_data
                                rescue EOFError 
                                    io_array.delete( stderr )
                                end
                            end

                            if blk
                                if out_data || err_data
                                    blk.call( out_data, err_data, nil )
                                end
                            end
                        end

                        thr = wait_thr
                    end
                    if blk
                        blk.call( nil, nil, thr.value )
                    end
                end
            end
        end
    end

    class Repo
        include AttributeChain
        attr_chain :bup_root
        attr_reader :name

        def initialize(name)
            @name = name
        end

        def exists?
            @bup_root = File.expand_path @bup_root
            File.exists? @bup_root
        end
    end

    class Task
        include AttributeChain
        attr_chain :source, :repo
        attr_reader :name

        def initialize(name)
            @name = name
        end

        def exists?
            @source.exists? and @repo.exists?
        end

        def branch_name
            @source.name
        end

        def cmd_index(no_update=false, silent =false )
            @source.execute_bash

            [ "bup","-d", bup_root_path, "index", no_update ? nil : "-u", silent ? "" : "-m",  "-f", index_file_path, opt_no_check_device, opt_exclude, source.path ].flatten .map{ |e| "\"#{e}\"" }.join(" ")
        end

        def cmd_save
            [ "bup", "-d", bup_root_path, "save", "-f", index_file_path, "-n", branch_name, source.path ].flatten.map{ |e| "\"#{e}\"" }.join(" ") 
        end

        def opt_no_check_device
            @source.external_disk? ? "--no-check-device" : ""
        end

        def bup_root_path
            @repo.bup_root
        end

        def index_file_path
            [ bup_root_path, "#{@source.name}.index" ].join("/")
        end

        def opt_exclude
            @source.exclude_files.map{ |f| [ "--exclude-from", f.path ] }
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

        def compile
            sources = @sources
            @sources = {}
            sources.each_pair do |name, source |
                @sources[name.to_sym] = source
            end

            repos = @repos
            @repos = {}
            repos.each_pair do |name, repo |
                @repos[name.to_sym] = repo
            end

            @tasks.each_pair do |name, task|
                if @sources.include? task.source.to_sym
                    task.source( @sources[task.source.to_sym] )
                else
                    raise "Unkown source #{task.source.to_sym} defined in #{name}"
                end
                if @repos.include? task.repo.to_sym
                    task.repo( @repos[task.repo.to_sym] )
                else
                    raise "Unkown repo #{task.repo.to_sym} defined in #{name}"
                end
            end
        end

        def self.parse(config)
            filename = "INIT_CFG_FILE"
            cfg = Config.new
            if config.is_a?(Pathname)
                filename = config.to_s
                config = config.read
            end

            cfg.instance_eval(config, filename)
            cfg.compile
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
