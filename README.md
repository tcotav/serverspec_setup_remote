## Testing Servers With Serverspec

We'll walk through a more elaborate example of using serverspec to verify server configuration.  For the demo, our target environment will be a tomcat front end along with a database backend.  We'll assume that those things exist for this article, but we'll provide files so you can test the full setup and testing in your own environment.

First up, let's make sure that you've got serverspec.

### ServerSpec Installation

(see also [the serverspec website](http://serverspec.org))

The first big requirement is that you've got ruby installed.  Go (here)[https://www.ruby-lang.org/] if you need help with that.

Clone this repo and then cd into it:

`git clone <this repo>`

We want to make sure our environment is ready to go.  We assume that you've got ruby and bundler all ready to go.

If you've got `bundler`, then simply

`bundle`

If you do NOT have `bundler`, then manually install

`gem install serverspec`

That's it for the grander setup of serverspec.  


