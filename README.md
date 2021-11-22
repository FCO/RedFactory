[![Actions Status](https://github.com/FCO/RedFactory/workflows/test/badge.svg)](https://github.com/FCO/RedFactory/actions)

NAME
====

RedFactory - A factory for testing code using Red

SYNOPSIS
========

```raku
# Your DB schema --------------------------------------------------------------------------------------
use Red;

model Post {...}

model Person {
   has UInt    $.id          is serial;
   has Str     $.first-name  is column;
   has Str     $.last-name   is column;
   has Str     $.email       is column;
   has Instant $.disabled-at is column{ :nullable };
   has Post    @.posts       is relationship(*.author-id, :model(Post));
}

model Post {
    has UInt    $.id         is serial;
    has Str     $.title      is column;
    has Str     $.body       is column;
    has UInt    $!author-id  is referencing(*.id, :model(Person));
    has Person  $.author     is relationship(*.author-id, :model(Person));
    has Instant $.created-at is column = now;
}


# Your factory configuration --------------------------------------------------------------------------
use RedFactory;

factory "person", :model(Person), {

   .first-name = "john";
   .last-name  = "doe";
   .email      = -> $_, :$number = .counter-by-model {
     "{ .first-name }{ $number }@domain.com"
   }

   .posts      = -> :$num-of-posts = 0 {
     factory-args $num-of-posts, "post"
   }

   trait "disabled", {
      .disabled-at = now
   }
}

factory "post", :model(Post), {

    .title = {
        "Post title { .counter-by-model }"
    }
    .body  = -> $_, :$title-repetition = 3 {
        (.title ~ "\n") x $title-repetition
    }
}


# Testing your imaginary controller helper ------------------------------------------------------------
use Test;

my $*RED-DB = factory-db;

my &get-recent-author's-posts'-titles =
    get-controller's-help("get-recent-author's-posts'-titles");

# Create the needed person with posts
my $author = factory-create "person", :PARS{ :10num-of-posts };

my @posts = get-recent-author's-posts'-titles $author.id, 3;

is-deeply @posts, ["Post title 10", "Post title 9", "Post title 8"];
```

DESCRIPTION
===========

RedFactory is a easier way of testing code that uses Red

AUTHOR
======

    <fernandocorrea@gmail.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2021 

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

