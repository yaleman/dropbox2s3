A terraform setup for transferring the contents of your Dropbox account to s3

# Building the infrastructure

1. Copy config.tf.example to config.tf

2. Generate an ssh key to use: `ssh-keygen -f sshkey -t ed25519`

3. Edit the configuration for your needs.
   
   1. Be sure to note that the aws profile is set a few times (because... reasons).
   2. Copy the public key (`sshkey.pub`) into the config.
   3. If you don't expect this to live long, you can remove the terraform s3 state handling, it's the last section. If you remove it, state will be kept local to the device you're running terraform from, but since this should be a one-shot thing, you should be fine.

4. Once you're ready to go, let's run Terraform!
   
   1. `terraform init` to set up terraform.
   2. `terraform plan` to sanity (and validity) check your config.
   3. CHECK TO SEE WHAT IT'S DOING
   4. `terraform apply` when you're ready to stand things up.

5. Once terraform has successfully run, it should output an ssh string to use, but also the hostname. (It should be something like `ssh -i sshkey ubuntu@ec2-3-90-26-24.compute-1.amazonaws.com`)

# Connecting Dropbox and doing the sync

1. ssh to the instance
   
   1. If you get something like this: `ssh: connect to host ec2-3-90-26-24.compute-1.amazonaws.com port 22: Connection refused` just wait a minute and try again, it's probably just booting.
   2. If it keeps happening, check your source IP hasn't changed.

2. Update the software and install the AWS cli: `sudo apt update; sudo apt -y upgrade; sudo apt -y install awscli` asdfasdfdsf

3. To install Dropbox:
   
   1. . Download and extract dropbox: `wget -O - https://www.dropbox.com/download?plat=lnx.x86_64 |tar zxf -`
   2. On Ubuntu bionic I had to install libatomic1 to make it work: `sudo apt install -y libatomic1`

4. Now to run Dropbox
   
   1. We'll run it in screen, so that it keeps running if you disconnect: `cd ~/.dropbox-dist; screen ./dropboxd` 
   2. It'll spew a bunch of unnecessary debug info, but after a while you'll be prompted to visit a URL similar to this: `This computer isn't linked to any Dropbox account... Please visit https://www.dropbox.com/cli_link_nonce?nonce=82d5878d6a55552bc8f2356ccda65847 to link this device.` Leave it running and visit the URL in your browser and connect your account.

5. Dropbox will check periodically and once it confirms it's working, you'll see `This computer is now linked to Dropbox. Welcome James` - but probably with your name, unless your name is James.

6. To disconnect from screen, press `Ctrl-A` and then `d`.

7. To check that it's synchronising, move to the Dropbox folder `cd ~/Dropbox` and run `ls -la; du -sh`. You'll see the list of files - hopefully including some of the contents of your Dropbox - and some cache things that it uses to work. It'll also show the size of the files so far.

8. Keep running `du -sh` periodically to watch it grow.

9. Once you're happy with the sync status, or you're impatient, syncronise your files to your s3 bucket. In this example my bucket is called `example-dropbox-bucket`. The command is `aws s3 sync --exclude ".dropbox*" ~/Dropbox/ s3://example-dropbox-bucket`

# Cleaning up

You won't want to just run `terraform destroy` as that'll kill off your s3 bucket with all your files in it 😄The plan is as follows:

1. Disable the `aws_s3_bucket` part of the terraform configuration.
   
   1. This is done by renaming `s3.tf` to `s3.tf.disabled` - alternatively just delete the file.

2. Remove the relevant state.
   
   1. `terraform state rm aws_s3_bucket.storage`

3. Check that it doesn't know about the s3 bucket anymore by running `terraform plan`
   
   1. If the "new plan" includes deleting the bucket, then run `terraform state list` and look for an aws_s3_bucket - you might have renamed the terraform object, or I screwed something up 😄
   
   2. If there's no changes, then that means a `terraform destroy` won't remove the bucket.

4. To remove the unneeded infrastructure, run `terraform destroy`

5. Double check the plan - it should be removing eight things (last time I counted) and type `yes` and hit enter to let it do the thing. If it fails to destroy the roles/policies, AWS and terraform are fighting again. You might need to go clean that up manually 😄

6. Time for 🍰
