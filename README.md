##Running Tests via ServerSpec


### Before you start, you need

  - a development chef server (hosted chef or otherwise)
  - a chef workstation 
  - vagrant (http://vagrantup.com)
  - serverspec (installed)[http://serverspec.org/]

 
### Set up Test Cookbook - jdemo

We're going to write a set of tests to run against a pair of "external" ubuntu virtual machines running our (jdemo tomcat application)[https://github.com/tcotav/cookbook-jdemo].  You'll note that the jdemo repo includes serverspec tests.  Those run against a virtualized local host.  With this doc, we want to show how you can use serverspec to verify any number of remote machines.

First up, lets make sure you've got the `jdemo` cookbook installed in your chef server.  A `Berksfile` is provided with this repo that will install the cookbook for you.

    $ berks
    Resolving cookbook dependencies...
    Fetching 'jdemo' from git://github.com/tcotav/cookbook-jdemo.git (at master)
    Fetching cookbook index from https://api.berkshelf.com...
    Using apt (2.4.0)
    Using jdemo (0.1.0) from git://github.com/tcotav/cookbook-jdemo.git (at master)
    Using tomcat (0.15.12)
    Using openssl (1.1.0)
    Using java (1.22.0)
    
    $ berks upload
    Skipping apt (2.4.0) (frozen)
    Skipping java (1.22.0) (frozen)
    Skipping jdemo (0.1.0) (frozen)
    Skipping openssl (1.1.0) (frozen)
    Skipping tomcat (0.15.12) (frozen)

You can do a quick verification of the upload using the `knife` command:

    $ knife cookbook list | grep jdemo
    jdemo                  0.1.0


### Set up the hosts

We've included a `Vagrantfile` that will spin up a pair of nodes that we'll test against.  

Open the `Vagrantfile` and change the variables at the top of the screen (and shown below) to match your environment.

    #
    # CHANGE THESE VARS
    #
    org_name=ENV['CHEF_ORG']
    
    chef_validation_key_path = "/Users/james/.chef/#{org_name}-validator.pem"
    #
    # END
    ########################################################

Just under the `CHANGE THESE` section there are three lines.  We're going to do a big of (potentially unnecessary) ruby + vagrant magic here.

    number_of_nodes=2
    chef_recipes = %w{jdemo::default}
    chef_roles=%w{}

What these lines set up for us is the number of vagrant vms we're going to spin up and also what recipes and roles we're going to apply.  I threw in the roles one even though we won't use it for this particular exercise.  `chef_recipes` is set to use the `jdemo` cookbook taht we've set up using `Berkshelf`.  We'll create two nodes for this go.

Here's the lame part of this particular test.  We'll need to set the hostnames that we're targeting in our `/etc/hosts` file so that we can hit 'em later using serverspec.


## Set up the Tests

There are two parts to the configuration for each of these hosts

1) .ssh/config file containing entries for each host tested
2) yml configuration describing tests for each host tested

To configure 1), we'll need to know what hosts we're setting up.  The naming convention used for the vagrant files in this doc is "jdemo-test-X" where x is the node number starting from 0.  So for the default vagrant file we've got two nodes so we're working with hosts jdemo-test-0 and jdemo-test-1.  However, here in laptop-land, we don't have working DNS so we're going to use the IP of the boxes instead.  The alternative to this is to add entries to the `/etc/hosts` file.  Your call...  IP is easier, but in more regular usage we would definitely use hostnames.


1)  First off, setting up the ssh config so that we can just magically get on to the hosts.  Edit file `~/.ssh/config` and add the following lines: 

```
Host 192.168.56.16*
     User vagrant.
     IdentityFile ~/.vagrant.d/insecure_private_key
```

In parallel to that, we want to drop entries into the `properties.yml` for each host including the tests that we haven't quite gotten around to writing yet.  

```
# first vagrant host
# use hostname if you can here
#jdemo-test-0:
192.168.56.160:
  # tests to run - found in spec/
  :roles:
  - ubuntu
  - jdemo
  fake-var: 1.1.14


# second vagrant host
#jdemo-test-1:
192.168.56.161:
  # tests to run - found in spec/
  :roles:
  - ubuntu
  - jdemo
  fake-var: 1.1.14
```

Now its time to define the `ubuntu` and `jdemo` that we reference in our `properties.yml` `roles` section.


Adding tests
============

The main script picks up whatever is in the role directories.  The roles from `properties.yml` correspond to the directory names present in the `spec` directory.

First lets make the roles.

    $ mkdir -p spec/ubuntu
    $ mkdir -p spec/jdemo

Then lets create some test files.  The rules for a file to be executed by serverspec is that they

  - must exist in a `spec/<role>` subdirectory
  - must be of the format `*_spec.rb`

Let's create some placeholder files first:

    $ touch spec/ubuntu/ubuntu_host_spec.rb
    $ touch spec/jdemo/jdemo_spec.rb

Edit the file `spec/ubuntu/ubuntu_host_spec.rb`
  
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


That looks pretty cool right?  Well, it doesn't do much other than confirm that a `vagrant` user and group have been added and verifies their gid/uid.  The idea for this role and respective set of tests is to verify operating system customizations you expect to be done to the target host.  If you don't have any of these -- don't use this role for the host you're targeting.  Simple as that.

Next we have our first application level serverspec test. 
 
    require 'spec_helper'
    
    # confirm the java install
    describe command('java -version') do
      its(:stderr) { should match /java version \"1.7/ }
      it { should return_exit_status 0 }
    end
    
    describe port(8080) do
      it { should be_listening }
    end
    
There's more we can add here later, but let's roll with this for right now.  To run the test, we just change to our working root directory and run the `rake` command.

    $ rake
    target - 192.168.56.160
    
    /opt/chefdk/embedded/bin/ruby -S rspec spec/jdemo/jdemo_spec.rb spec/ubuntu/ubuntu_host_spec.rb
    .......
    
    Finished in 0.11187 seconds
    7 examples, 0 failures
    target - 192.168.56.161
    
    /opt/chefdk/embedded/bin/ruby -S rspec spec/jdemo/jdemo_spec.rb spec/ubuntu/ubuntu_host_spec.rb
    .......
    
    Finished in 0.1142 seconds
    7 examples, 0 failures

We passed all of our tests.  Ok, let's see what a failure looks like.  Connect to the second vagrant box and shut down the `tomcat` service.

    $ vagrant ssh jdemo-test-1
    
and then on the box, we'll want to run the following and then exit the box:

    vagrant@jdemo-test-1:~$ sudo /etc/init.d/tomcat6 stop
     * Stopping Tomcat servlet engine tomcat6
  
    vagrant@jdemo-test-1:~$ exit

Ok, now lets run our serverspec test again.

    $ rake
    target - 192.168.56.160
    
    /opt/chefdk/embedded/bin/ruby -S rspec spec/jdemo/jdemo_spec.rb spec/ubuntu/ubuntu_host_spec.rb
    .......
    
    Finished in 0.1217 seconds
    7 examples, 0 failures
    target - 192.168.56.161
    
    /opt/chefdk/embedded/bin/ruby -S rspec spec/jdemo/jdemo_spec.rb spec/ubuntu/ubuntu_host_spec.rb
    ..F....
    
    Failures:
    
      1) Port "8080" should be listening
         Failure/Error: it { should be_listening }
           sudo netstat -tunl | grep -- :8080\
           expected Port "8080" to be listening
         # ./spec/jdemo/jdemo_spec.rb:10:in `block (2 levels) in <top (required)>'
    
    Finished in 0.12131 seconds
    7 examples, 1 failure
    
    Failed examples:
    
    rspec ./spec/jdemo/jdemo_spec.rb:10 # Port "8080" should be listening
    /opt/chefdk/embedded/bin/ruby -S rspec spec/jdemo/jdemo_spec.rb spec/ubuntu/ubuntu_host_spec.rb failed
   
    
Lets all cheer this one time for that failure.  So now you've seen what a failed test looks like.

###
