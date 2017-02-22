require 'test_helper'

include Easybup

class EasybupUnitTest < Minitest::Test
    context "Config" do
        should "parse default config file" do
            cfg = Config.parse( INIT_CFG_FILE )
            assert_includes cfg.sources, :sample_source
            assert_includes cfg.repos, :sample_root
            assert_includes cfg.tasks, :task0

            assert_equal "/path/to/your/source_file", cfg.sources[:sample_source].path
            assert_equal "/path/to/your/bup_root", cfg.repos[:sample_root].bup_root
            assert_equal "sample_source", cfg.tasks[:task0].source
            assert_equal "sample_root", cfg.tasks[:task0].repo

            assert_equal "task0", cfg.default

        end
    end
end
