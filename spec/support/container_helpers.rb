require 'stringio'

module ContainerHelpers
  shared_context 'cgroup file' do
    let(:cgroup_file) { StringIO.new }

    before do
      allow(File).to receive(:exist?).and_call_original

      expect(File).to receive(:exist?)
        .with('/proc/self/cgroup')
        .and_return(true)

      allow(File).to receive(:foreach).and_call_original

      allow(File).to receive(:foreach)
        .with('/proc/self/cgroup') do |&block|
          cgroup_file.each { |line| block.call(line) }
        end
    end
  end

  # rubocop:disable Layout/LineLength
  shared_context 'non-containerized environment' do
    include_context 'cgroup file'

    let(:platform) { nil }
    let(:lines) { 13 }

    before do
      cgroup_file.puts '12:hugetlb:/'
      cgroup_file.puts '11:devices:/user.slice'
      cgroup_file.puts '10:pids:/user.slice/user-1000.slice/user@1000.service'
      cgroup_file.puts '9:memory:/user.slice'
      cgroup_file.puts '8:cpuset:/'
      cgroup_file.puts '7:rdma:/'
      cgroup_file.puts '6:freezer:/'
      cgroup_file.puts '5:perf_event:/'
      cgroup_file.puts '4:cpu,cpuacct:/user.slice'
      cgroup_file.puts '3:blkio:/user.slice'
      cgroup_file.puts '2:net_cls,net_prio:/'
      cgroup_file.puts '1:name=systemd:/user.slice/user-1000.slice/user@1000.service/gnome-terminal-server.service'
      cgroup_file.puts '0::/user.slice/user-1000.slice/user@1000.service/gnome-terminal-server.service'
      cgroup_file.rewind
    end
  end

  shared_context 'non-containerized environment with VTE' do
    include_context 'cgroup file'

    let(:platform) { 'user' }
    let(:terminal_id) { '6fec48c4-1f82-4313-a1c2-29e205a96958' }
    let(:lines) { 13 }

    before do
      cgroup_file.puts '12:hugetlb:/'
      cgroup_file.puts "11:devices:/#{platform}.slice"
      cgroup_file.puts "10:pids:/#{platform}.slice/user-1000.slice/user@1000.service"
      cgroup_file.puts "9:memory:/#{platform}.slice"
      cgroup_file.puts '8:cpuset:/'
      cgroup_file.puts '7:rdma:/'
      cgroup_file.puts '6:freezer:/'
      cgroup_file.puts '5:perf_event:/'
      cgroup_file.puts "4:cpu,cpuacct:/#{platform}.slice"
      cgroup_file.puts "3:blkio:/#{platform}.slice"
      cgroup_file.puts '2:net_cls,net_prio:/'
      cgroup_file.puts "1:name=systemd:/#{platform}.slice/user-1000.slice/user@1000.service/gnome-terminal-server.service"
      cgroup_file.puts "0::/#{platform}.slice/user-1000.slice/user@1000.service/app.slice/app-org.gnome.Terminal.slice/vte-spawn-#{terminal_id}.scope"
      cgroup_file.rewind
    end
  end

  shared_context 'Docker environment' do
    include_context 'cgroup file'

    let(:platform) { 'docker' }
 