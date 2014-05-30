![Level 11](Level11.png)
## Serverspec Test Setup For Remote Hosts


### Intro

(Serverspec)[http://serverspec.org] is a great way to check if your servers are configured as you expect.  From the website, "serverspec tests your servers' actual state through ssh access".  Of the current scripting packages, I'm a huge fan of serverspec because I can use the same tests in development all the way out through production.  A prod box isn't working right?  We've automated here a way to make sure that it is in the state we expect for our app.  Below I lay out a basic flexible framework for using `serverspec` with a variety of nodes and applications.

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


### Set up the Tests

There are two parts to the configuration for each of these hosts

  - .ssh/config file containing entries for each host tested
  - yml configuration describing tests for each host tested

To configure the ssh, we'll need to know what hosts we're setting up.  The naming convention used for the vagrant files in this doc is "jdemo-test-X" where x is the node number starting from 0.  So for the default vagrant file we've got two nodes so we're working with hosts jdemo-test-0 and jdemo-test-1.  However, here in laptop-land, we don't have working DNS so we're going to use the IP of the boxes instead.  The alternative to this is to add entries to the `/etc/hosts` file.  Your call...  IP is easier, but in more regular usage we would definitely use hostnames.


1)  First off, setting up the ssh config so that we can just magically get on to the hosts.  Edit file `~/.ssh/config` and add the following lines: 

    Host 192.168.56.16*
         User vagrant.
         IdentityFile ~/.vagrant.d/insecure_private_key

In parallel to that, we want to drop entries into the `properties.yml` for each host including the tests that we haven't quite gotten around to writing yet.  

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

Now its time to define the `ubuntu` and `jdemo` that we reference in our `properties.yml` `roles` section.


### Adding tests

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

We passed all of our tests.  Ok, let's see what a failure looks like.
  

### Let's Fail Spectacularly
  
First, lets set up our failure condition.  Connect to the second vagrant box and shut down the `tomcat` service.

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

Okay, now lets go back in to that host and turn tomcat back on so that our tests succeed.  Connect to the vagrant host.

    $ vagrant ssh jdemo-test-1

On that host, turn the service back on:

    vagrant@jdemo-test-1:~$ sudo /etc/init.d/tomcat6 start
     * Starting Tomcat servlet engine tomcat6                                           [ OK ]
      
    vagrant@jdemo-test-1:~$ exit

Okay, now lets write more tests!

### Flushing Out Our Potential Tests

What else should we test?  Well, lets look at our cookbook and see what resources we're working on and what other cookbooks we call.

Cookbook summary

  - update apt packages
  - install tomcat package
  - get remote war file
  - install war file
  - start service
 
There's one other thing that we can note from looking at the cookbooks -- in the `attributes/default.rb` we specify that we want to use `openjdk` version `7`. 

So we're going to add that to our test.

  - openjdk 7 is installed
  
Those are items we found in our cookbooks.  Let's translate them into something we can use -- serverspec items.  

### Into Serverspec

The first thing we need to test is where does this fit into the role directories that we've set up.  We've got two directories:
 
 - jdemo
 - ubuntu

This maps to an OS cookbook and an app cookbook which is a pretty good pattern to follow.

Pretty clearly the bulk of the list falls into jdemo.  The only exception is the status of apt which we'll deal with separately.  Inside jdemo there is just one spec file.  Serverspec will tick through all the files in a subdirectory so you can either dump everything into one big file or break it out into a bunch of files.  Whatever method suits your madness.

For this, we'll put it all into `jdemo_spec.rb`
 
First off, the `java` install.  The way that we did it was fairly generic command line parse that looked like this:

    # confirm the java install
    describe command('java -version') do
      its(:stderr) { should match /java version \"1.7/ }
      it { should return_exit_status 0 }
    end

Another way we could do this is to confirm that `apt` installed the package with the following:
    
    describe package('openjdk-7-jdk') do
      it { should be_installed }
    end

Great right?  Well maybe.  What we just did there was tie the test to ubuntu.  *We crossed the streams.*  Maybe that's fine in our environment.  The (chef resource `package`)[http://docs.opscode.com/resource_package.html] itself allows for a number of different packages types to be handled (windows, solaris, freebsd, ... etc), but most likely the package name won't be `openjdk-7-jdk`.  We could probably work around that if that was what was needed.  Fortunately, we don't need to work around it.

We can do the same thing to test of `tomcat` is installed (with the same limitations).

    describe package('tomcat6') do
      it { should be_installed }
    end

We know the service is running by port 8080 being bound so that's checked already.

What about the war file?  Is it in place as the first part?

    describe file('/var/lib/tomcat6/webapps/punter.war') do
      it { should be_file }
    end

and then as the second item there -- did the war get opened up and used:

    describe file('/var/lib/tomcat6/webapps/punter') do
      it { should be_directory }
    end
    
Wow -- look at us go!  Give it a test using the `rake` command and hopefully it all works out.

You should see this twice in the serverspec output:

    11 examples, 0 failures
    
### 

Created by James Francis - <a href="https://twitter.com/tcotav" class="twitter-follow-button" data-show-count="false">Follow @tcotav</a>
                           <script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+'://platform.twitter.com/widgets.js';fjs.parentNode.insertBefore(js,fjs);}}(document, 'script', 'twitter-wjs');</script>