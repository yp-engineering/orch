# Orch

orch - uses a Yaml file to specify jobs that can be delpoyed to Mesos' Marathon and Chronos frameworks.

## Installing this tool

Run the following command:
```
$> gem install orch
```
(you might need to sudo)

Once the gem is installed, the command orch will be in your $PATH

## Usage

Type "orch help" to get the list of commands and "orch help _command_" to get list of options for a given command.

The general usecase is to run "orch deploy _job_spec_" to deploy a configuration to to Marathon or Chronos.  A given job_spec can contain specifications for many jobs and for multiple environments.  Various options to the deploy command gives control to exactly what is deployed. 

## Job spec format

The orch Yaml format is really a wrapper for multiple Marathon or Chronos job descriptions.  The format is based on yaml.  To get a basic understanding of Yaml files check out: http://www.yaml.org/start.html

The basic orch syntax is as follows:
```
version: 1.0
applications:
  - kind: Chronos
    chronos_spec:
      ...
```

The **version:** field must currently always be 1.0.  Eventually, this tool may need to support a revised format and this can be used to support multiple versions.

The **applications:** field contains an array of Chronos or Marathon configurations.  Each array must have a **kind:** field with a value of _Chronos_ or _Marathon_ which simply tells orch what type of config this is.  Depending on the value of **kind:** a field of **chronos_spec:** or **marathon_spec:** is also required.

The values of **chronos_spec:** should simply be the yaml equivelent of the chronos json messages.  You can find documentation for chronos json format here: https://mesos.github.io/chronos/docs/api.html


Likewise, the values of **marathon_spec:** should simply be the yaml equivelent of the marathon json messages.  You can find documentation for marathon json format here: https://mesosphere.github.io/marathon/docs/rest-api.html

So far all we have is a different way to specify a job.  The real power of orch will come from using meta data to act on these configs in more interesting ways...

### Deployment vars

The **deploy_vars:** field allows you to define some values that can be used to drive deployment of the same config for multiple uses.  Often it is useful to have *dev*, *test* & *prod* environments for our application.  Generally we want to use the same specification for all environments but we need a way to differentiate them and allow the app at run time to know what environment it is running in.

Let's start with an example:
```
deploy_vars:
  DEPLOY_ENV:
    - dev
    - test
    - prod
```
This example will define an environment variable named **DEPLOY_ENV**.  (You can name it whatever you want.)  We are defining it here to have values of *dev*, *test*, and *prod*.

You then would need to specify that variable in your application sections like this:
```
version: 1.0
deploy_vars:
  DEPLOY_ENV:
    - dev
    - test
    - prod
applications:
  - kind: Chronos
    DEPLOY_ENV: dev
    chronos_spec:
      name: "myapp-{{DEPLOY_ENV}}"
      ...
  - kind: Chronos
    DEPLOY_ENV: prod
    chronos_spec:
      name: "myapp-{{DEPLOY_ENV}}"
      ...
```

When orch runs it will insert the environment variable into the *env* or *environmentVariables* sections of your spec.  However, you can also use the **--deploy-env** command line option to tell orch to only deploy a paticular environment.  You can also use the substitution feature to use the value of your environment varaible in other parts of the config like name.  *(e.g. `name: "myapp-{{DEPLOY_ENV}}"` would substitute to `name: "myapp-dev"` for the dev environment)*

### Alternative way to set environment variables

Chronos and Marathon use different syntx to specify environment variables.  Also, you may want to specify certain variables consistently across several applications in your orch spec.  The **env:** field provides a way to do that with a nice clean syntax.


The env field could be used at the top level of the spec to be used across all applications in the spec:
```
version: 1.0
env:
  GOOGLE_URL: http://www.google.com
  YP_URL: http://www.yp.com
  applications:
    ...
```

Or you can also specify it at the application level as an alternative syntax to specifying it in the *marathon_spec:* or *chronos_spec:* sections - like this:
```
version: 1.0
env:
  GOOGLE_URL: http://www.google.com
  YP_URL: http://www.yp.com
  applications:
    - kind: Marathon
      env:
        GOOGLE_URL: http://www.google.com
        YP_URL: http://www.yp.com        
      marathon_spec:
        ...
```

Lower level definitions of an env var will superceed a higher level version.  That is if you specify an env value in the *marathon_spec* or *chronos_spec* level it will override anything set at the *app* or *orch* level.
### Yaml anchors and aliases

The nice thing about using Yaml as the spec format is the ability to use Yaml's anchors (&) and alias (*) syntax.  This allows you to specify sections of your configuration that can be reused across multiple jobs.  Typically if you have a job for multiple deployment environments you what them all to have the same spec - except perhaps override one or two things.  (Like an envionment value or the docker image.)

We will refer you to other documentation on the internet on how to use Yaml anchors and aliases.  However, you can take a look at a couple of the [provided examples](examples/Examples.md) to see how you might use Yaml to its fullest.

### Substition

A primary use case of **orch** is to use the tool from within a Makefile.  You may want to subsitite parts of you configuration from vairables in your Makefile.  In the *Deployment vars* section we showed you how you can use deployment vars as substitution values in other parts of the configuration.

**Orch** also provides the *--subst* option to provide a way to pass additional substitution vars when running your configuration.  A common use case might be to pass in the tag for a Docker image that is managed by your Makefile.  Here is an example:
```
todo: provide an example
```

TODO: finish this section

### Bamboo

[Bamboo](https://github.com/QubitProducts/bamboo) is a tool that creates an HAProxy for providing an easier way to get to a farm of web servers hosted by Marathon.  You define the Marathon id of the application you want to load balance and an acl to tell HAProxy what url to direct to your marathon application.

Orch provides a way to also configure your Bamboo server from your orch config.  Here is an example:
```
version: 1.0
applications:
  - kind: Marathon
    marathon_spec:
      ...
    bamboo_spec:
      acl: "hdr(host) -i test-web.int.yp.com"
```

An additional *bamboo_spec:* field is added to the Marathon application at the same level as the *marathon_spec:* field.  The *bamboo_spec:* field contains one field called *acl:*.  The simply has a acl rule for HAProxy.  See Bamboo documentation for more details.

Note: you will also need to set the **bamboo_url:** feild of your configutation.

### TODO: section on vault

## Configuration Options

There are a few ways to configure orch to know about the urls for various mesos services.  These provide options
for various automation and deployment scenerios.

The first option is to set up a config file with the urls for your Mesos frameworks.  Run the following command to interactively create a config file.
```
$> orch config
```

The file ~/.orch/config.yaml would contain values for "chronos_url" and "marathon_url".

You can also specify the framework urls directly in your configuration.  There are two places in the specification that could the url can be set.  You would use the keys chronos_url:, marathon_url: or bamboo_url:
Here is an example:
```
version: 1.0
config:
  chronos_url: http://chronos.mycompany.com:8080
applications:
  - kind: Marathon
    marathon_url: http://marathon.mycompany.com
    marathon_spec:
      ...
    bamboo_url: http://bamboo.mycompany.com
    bamboo_spec:
      acl: "hdr(host) -i web.example.com"
```

A url in the config section would apply to all applications in the specification.  A url at the application level would superceed any definitions in the config section.  This can be useful if you have a specification that needs to deploy to multiple clusters such as in a multi-datacenter scenerio.  Any urls specified in a YAML specification would override those in the .orch/config.yaml file.

Finally, you can also pass --chronos_url or --marathon_url options to the "orch deploy" command to override all other specifications.  You may want to use this option in automated deployment scenerios where you want to manage were things get deployed in another system.

In more robust implementations you may have a list of redundant frameworks you can deploy to.  All of these configurations support passing a semi-colon seperated list of URLs.  If network related errors occur Orch will attempt to call additional specified URLs.  Also, if your framework has basic auth credentials required you may specify those credentials in the config like this:  http://user:password@myframework.mycompany.com

## Examples

The examples directory contains various examples of the features of orch.  
View [documentation there](examples/Examples.md) for more details.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/orch/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
