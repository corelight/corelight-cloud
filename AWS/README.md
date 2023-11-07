# AWS

AWS specific deployment scripts.

## Cloud Formation

A Cloud Formation template for deploying Corelight Sensors.

## Dependencies

* Install [Task][]

[Task]: https://taskfile.dev/

### Deployment Instructions

Edit the vars section of the `Taskfile.yml` file with your cloud environment's
configuration.

#### Sensor

Create a new stack:

    $ task cfn:sensor:create

Update existing stack:

    $ task cfn:sensor:update

## Testing

Execute tests:

    $ task test

List helpful targets:

    $ task
