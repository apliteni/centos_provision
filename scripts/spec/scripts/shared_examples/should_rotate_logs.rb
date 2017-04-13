RSpec.shared_examples_for 'should rotate log files' do |log_file_name:|
  shared_examples_for 'should create' do |filename|
    specify do
      run_script
      expect(File).to be_exists(filename)
    end
  end

  shared_examples_for "should move old #{log_file_name} to" do |newname|
    specify do
      old_content = IO.read(log_file_name)
      run_script
      expect(IO.read(newname)).to eq(old_content)
    end
  end

  context 'log files does not exists' do
    it_behaves_like 'should create', log_file_name
  end

  context 'install.log exists' do
    before { IO.write(log_file_name, 'some log') }

    it_behaves_like 'should create', log_file_name

    it_behaves_like "should move old #{log_file_name} to", "#{log_file_name}.1"
  end

  context "#{log_file_name}, #{log_file_name}.1 exists" do
    before { IO.write(log_file_name, 'some log line') }
    before { IO.write("#{log_file_name}.1", 'some log line in old log') }

    it_behaves_like 'should create', log_file_name

    it_behaves_like "should move old #{log_file_name} to", "#{log_file_name}.2"
  end
end
