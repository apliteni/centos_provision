RSpec.shared_context 'read inventory from log' do
  after do
    @inventory = Inventory.new
    @inventory.read_from_log(@log)
  end
end
