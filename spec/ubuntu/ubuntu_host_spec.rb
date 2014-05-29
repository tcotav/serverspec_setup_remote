require 'spec_helper'


users=[
    {'name' => 'vagrant', 'uid' => 900}
]

groups=[
    {'name' => 'vagrant', 'gid' => 900}
]

users.each do |user|
  describe user(user['name']) do
    it { should exist }
    it { should have_uid user['uid'] }
  end
end

groups.each do |group|
  describe group(group['name']) do
    it { should exist }
    it { should have_gid group['gid'] }
  end
end


