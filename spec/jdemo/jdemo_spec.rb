require 'spec_helper'

# confirm the java install
describe command('java -version') do
  its(:stderr) { should match /java version \"1.7/ }
  it { should return_exit_status 0 }
end

describe port(8080) do
  it { should be_listening }
end