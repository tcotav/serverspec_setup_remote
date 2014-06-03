# -*- mode: ruby -*-
# vi: set ft=ruby :

#
# CHANGE THESE VARS
#
org_name=ENV['CHEF_ORG']
box_name='#{box_name}'
chef_validation_key_path = "#{ENV['HOME']}/.chef/#{org_name}-validator.pem"
number_of_nodes=2
chef_recipes = %w{jdemo::default}
chef_roles=%w{}
#
# END
########################################################


# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "chef/ubuntu-12.04"
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", "512"]
  end
  config.omnibus.chef_version = :latest
  (0..(number_of_nodes-1)).each do |node_num|
    config.vm.define "#{box_name}-#{node_num}"  do |box|
      box.vm.hostname = "#{box_name}-#{node_num}"
      #box.vm.network "public_network"
      box.vm.network "private_network", ip: "192.168.56.16#{node_num}"

      box.vm.provision "chef_client" do |chef|
        chef.validation_client_name = "#{org_name}-validator"
        chef.validation_key_path = "#{chef_validation_key_path}"
        chef.chef_server_url = "https://api.opscode.com/organizations/#{org_name}"
        chef_recipes.each do |chef_recipe|
          chef.add_recipe "#{chef_recipe}"
        end
        chef_roles.each do |chef_role|
          chef.add_role "#{chef_role}"
        end
        chef.node_name = "#{box_name}-#{node_num}"
        chef.provisioning_path = "/etc/chef"
        chef.log_level = :info
        chef.delete_node = true
        chef.delete_client = true
      end
    end
  end
end

