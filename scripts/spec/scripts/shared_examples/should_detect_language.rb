RSpec.shared_examples_for 'should detect language' do
  describe 'invoked with `-L en` option' do
    let(:options) { '-L en' }

    it_behaves_like 'should print to', :log, 'Language: en'
  end

  describe 'invoked with `-L ru` option' do
    let(:options) { '-L ru' }

    it_behaves_like 'should print to', :log, 'Language: ru'
  end

  context 'set unsupported language' do
    let(:options) { '-L xx' }

    it_behaves_like 'should exit with error', "-L: language 'xx' is not supported"
  end

  # TODO: Detect language from LC_MESSAGES
  describe 'detects language from LANG environment variable' do
    context 'LANG=ru_RU.UTF-8' do
      let(:env) { {LANG: 'ru_RU.UTF-8'} }

      it_behaves_like 'should print to', :log, 'Language: ru'
    end

    context 'LANG=ru_UA.UTF-8' do
      let(:env) { {LANG: 'ru_UA.UTF-8'} }

      it_behaves_like 'should print to', :log, 'Language: ru'
    end

    context 'LANG=en_US.UTF-8' do
      let(:env) { {LANG: 'en_US.UTF-8'} }

      it_behaves_like 'should print to', :log, 'Language: en'
    end

    context 'LANG=de_DE.UTF-8' do
      let(:env) { {LANG: 'de_DE.UTF-8'} }

      it_behaves_like 'should print to', :log, 'Language: en'
    end
  end
end
