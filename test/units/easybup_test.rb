require 'test_helper'

include Easybup

class EasybupUnitTest < Minitest::Test
    context "Config" do
        context "#parse" do
            should "parse default config file" do
                cfg = Config.parse( INIT_CFG_FILE )
                assert_includes cfg.sources, :sample_source
                assert_includes cfg.repos, :sample_root
                assert_includes cfg.tasks, :task0

                assert_equal "/path/to/your/source_file", cfg.sources[:sample_source].path
                assert_equal "/path/to/your/bup_root", cfg.repos[:sample_root].bup_root
                assert_equal :sample_source, cfg.tasks[:task0].source.name
                assert_equal :sample_root, cfg.tasks[:task0].repo.name

                assert_equal "task0", cfg.default
            end
        end
    end

    context "Source" do
        context "#exists?" do
            setup do
                @source = Source.new( "source" )
                @source.path( "source_path" )
            end

            should "return true if specified path is exists" do
                File.expects(:exists?).with(File.expand_path("source_path")).returns( true )
                assert @source.exists?
            end

            should "return false if specified path is not exists" do
                File.expects(:exists?).with(File.expand_path("source_path")).returns( false )
                refute @source.exists?
            end
        end

        context "#run_bash" do
            setup do
                @source = Source.new( "source" )
                @source.exclude_bash( "echo Hello" )
            end
            should "read stdout of bash command" do
                index = 0
                @source.run_bash() do |out,err,status|
                    assert index < 2
                    if index == 0
                        assert_equal "Hello\n", out
                        assert_nil err
                    elsif index == 1
                        puts "[#{status.exitstatus}]"
                    end
                    index += 1
                end

            end
        end

        context "#execute_bash" do
            setup do
                @source = Source.new( "source" )
                @source.exclude_bash( "echo Hello" )
            end

            should "write stdout of bash command to a tempfile" do
                assert_equal 0, @source.exclude_files.length
                @source.execute_bash() 
                assert_equal 1, @source.exclude_files.length
                assert_equal "Hello\n", @source.exclude_files.first.read
            end
        end
    end

    context "Task" do
        context "#cmd_index" do
            should "has --exclude-from bash cmd" do
                task = Task.new(:task)
                source = Source.new( "source" )
                source.path( "~/source" )
                source.exclude_bash( "echo Hello" )

                repo = Repo.new( :repo )
                repo.bup_root( "~/buproot" )
                
                task.source(source)
                task.repo(repo)
                cmd = task.cmd_index assert cmd.index( "--exclude-from #{source.exclude_files.first.path}" )
            end
        end
    end
end
