require './test/csv_test_helper'
require './lib/hammer_cli_csv'

module Resources
  class TestContentHostsUsage < MiniTest::Unit::TestCase
    def test_usage
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --help})
      }
      assert_equal '', stderr
      assert_equal stdout, <<-HELP
Usage:
     csv content-hosts [OPTIONS]

Options:
 --continue-on-error           Continue processing even if individual resource error
 --export                      Export current data instead of importing
 --file FILE_NAME              CSV file (default to /dev/stdout with --export, otherwise required)
 --organization ORGANIZATION   Only process organization matching this name
 --subscriptions-only          Export only detailed subscription information
 -h, --help                    print help
 -v, --verbose                 be verbose
HELP
      stop_vcr
    end
  end

  class TestContentHostsImport < MiniTest::Unit::TestCase
    def test_create_and_update
      start_vcr
      set_user 'admin'

      @hostname = "testhost1"

      file = Tempfile.new('content_hosts_test')
      file.write("Name,Count,Organization,Environment,Content View,Host Collections,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions\n")
      file.write("#{@hostname},1,Test Corporation,Library,Default Organization View,,No,,RHEL 6.4,x86_64,1,4,1,,,\n")
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Creating content host '#{@hostname}'...done"

      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal stdout[0..-2], "Updating content host '#{@hostname}'...done"
      file.unlink

      stdout,stderr = capture {
        hammer.run(%W(host list --search name=#{@hostname}))
      }
      assert_equal '', stderr
      assert_equal stdout.split("\n").length, 5
      host_delete(@hostname)

      stop_vcr
    end
  end

  class TestContentHostsExport < MiniTest::Unit::TestCase
    def test_export
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --export --organization Test\ Corporation})
      }
      assert_equal '', stderr
      assert_equal stdout.split("\n")[0], "Name,Organization,Environment,Content View,Host Collections,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions"
      stop_vcr
    end

    def test_export_subscriptions
      start_vcr
      set_user 'admin'

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --export --subscriptions-only --organization Test\ Corporation})
      }
      assert_equal '', stderr

      # rubocop:disable LineLength
      assert_equal stdout.split("\n")[0], "Name,Organization,Environment,Content View,Host Collections,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscription Name,Subscription Type,Subscription Quantity,Subscription SKU,Subscription Contract,Subscription Account,Subscription Start,Subscription End"
      # rubocop:enable LineLength
      stop_vcr
    end
  end

  class TestContentHostsImport < MiniTest::Unit::TestCase
    # import a single line, testing that subscription is added
    def test_import_single_line
      start_vcr
      set_user 'admin'

      @hostname = 'testhypervisor1'

      file = Tempfile.new('content_hosts_test')
      # rubocop:disable LineLength
      file.write("Name,Organization,Environment,Content View,Host Collections,Virtual,Host,OS,Arch,Sockets,RAM,Cores,SLA,Products,Subscriptions\n")
      file.write("#{@hostname},Test Corporation,Library,Default Organization View,\"\",Yes,,RHEL 7.2,x86_64,2,3882752,1,\"\",\"69|Red Hat Enterprise Linux Server,290|Red Hat OpenShift Enterprise\",\"\"\"1|RH00001|Red Hat Enterprise Linux for Virtual Datacenters, Premium\"\"\"\n")
      # rubocop:enable LineLength
      file.rewind

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --verbose --file #{file.path}})
      }
      assert_equal '', stderr
      assert_equal "Creating content host '#{@hostname}'...done\n", stdout

      stdout,stderr = capture {
        hammer.run(%W{csv content-hosts --export --organization Test\ Corporation})
      }
      assert_equal '', stderr
      lines = stdout.split("\n")
      assert_equal 2, lines.count
      assert_match(/.*Test Corporation,Library,Default Organization View,"",Yes,,RHEL 7.2,x86_64,2,3882752,1.*/, lines[1])
      assert_match(/.*1|RH00001|Red Hat Enterprise Linux for Virtual Datacenters, Premium.*/, lines[1])
      host_delete(@hostname)

      stop_vcr
    end
  end
end
