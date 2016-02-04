require 'rails_helper'

shared_context 'setup celluloid' do
  before do
    Celluloid.boot
  end
  after do
    Celluloid.shutdown
  end
end
