---
title: "Compiling pothole from scratch"
description: "A nice and easy-to-follow tutorial for how to compile Pothole from scratch."
---

This tutorial covers only basic compilation for Pothole.
The instructions here can be used to compile code in the `main` branch and the `staging` branch.

For this tutorial, you will need:

* Nim: Which you can download from the [main webpage](https://nim-lang.org/) or from your package manager.
* git: You can get this from your package manager.
* Your favorite C compiler (gcc is recommended) 
* Some basic shell knowledge.

This tutorial assumes you are using a Linux machine
(real Linux, not WSL. You can do this in a VM or live CD if you really need Windows.)

## Clone the pothole repository{#cloning}

To get started, you need to clone the pothole repository. And here, you
will have to make a choice between the `main` branch and the `staging`
branch.

### What is main?

`main` is a branch that contains production-ready, tested and complete code.
We generally try to keep code here as stable as possible,
which means it's great for servers and other production environment.
We highly recommend you use this for your build unless you like living dangerously.

### what is staging?

`staging` is where the latest development on Pothole happens.
It contains all the brand new shiny features for you to play with.
The problem is that stability is not a priority and so because of that,
some bugs might not be fixed and some features might not be completely finished.
And also this branch changes every day, there is no solid versioning here
and you might find it hard to keep your server up-to-date.

We generally recommend the `staging` branch only to those who know what they are doing
or pothole developers who are experimenting with the latest features.

Now that you have chosen what branch you will clone,
run the following command (Make sure you have git installed)

`git clone https://gt.tilambda.zone/o/pothole/server.git -b YOUR_BRANCH`

Obviously replace `YOUR-BRANCH` with either `main` or `staging`

After the command exits, you will see a new directory called `server`, this is where the source code is.

## Building pothole.{#building}

Building pothole is as easy as running a single command.
But you will need to make a choice regarding database engines.

### Selecting a database engine.

With the use of compile-time directives, Pothole can add support for multiple database engines,
but there is a caveat: you can only add support for one database engine at a time.

This means a pothole binary with `sqlite` support is only able to open sqlite databases and nothing else.

1.  Sqlite

Pothole supports sqlite, for simple servers (1-5 users) this is good enough
although if you are going to host Pothole for more users then using Postgres is a good option.

The main benefit of using sqlite is that it is lightweight,
it does not require a database server to run in the background.
And if you are hosting only for yourself and you do not mind a bit of latency then sqlite is a good option.

2.  Postgres

*Note: as of now, postgres support is very limited-*

Pothole supports postgres, this is a good option for small servers that don't want latency
or for servers with more than 5 users.

Your performance and mileage with this database backend will vary
since it's not used very much in actual development.

## Building

Now it's time to actually build pothole. Open your shell and `cd`
to the new folder. Make sure you have nim and nimble installed for
this section.

Run `nimble build` and feel free to insert [any build options](/wiki/build-options/) at the end of this command.

You should now be able to see a `build/` directory,
this contains your build of Pothole.
You should also be able to see a `pothole` executable file,
this is pothole in its purest form, a simple binary.

You can just transfer this binary and the configuration file to your server and run it,
in which case, you will get a working pothole server but it's much better to put pothole behind an nginx proxy,
and to setup caching so you don't automatically generate from templates every single time you get a request.

Those setps are covered in the installation.