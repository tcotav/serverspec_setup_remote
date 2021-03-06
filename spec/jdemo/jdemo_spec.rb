require 'spec_helper'

# confirm the java install
describe command('java -version') do
  its(:stderr) { should match /java version \"1.7/ }
  it { should return_exit_status 0 }
end

describe port(8080) do
  it { should be_listening }
end

describe package('openjdk-7-jdk') do
  it { should be_installed }
end

describe package('tomcat6') do
  it { should be_installed }
end

describe file('/var/lib/tomcat6/webapps/punter.war') do
  it { should be_file }
end

describe file('/var/lib/tomcat6/webapps/punter') do
  it { should be_directory }
end