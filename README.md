[![Actions Status](https://github.com/FCO/RedFactory/workflows/test/badge.svg)](https://github.com/FCO/RedFactory/actions)

NAME
====

RedFactory - A factory for testing code using Red

SYNOPSIS
========

```raku
use Red;

# Your DB schema

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

# Your factory configuration

use RedFactory;

factory "person", :model(Person), {

   .first-name = "john";
   .last-name  = "doe";
   .email      = { "{ .first-name }{ .PAR("number") // .counter-by-model }@domain.com" }

   .posts      = { factory-args .PAR("num-of-posts") // 0, "post" }

   trait "disabled", {
      .disabled-at = now
   }
}

factory "post", :model(Post), {

    .title = { "Post title { .counter-by-model }" };
    .body  = { (.title ~ "\n") x (.PAR("title-repetition") // 3) }

}

# Testing your imaginary controller helper

use Test;

my $*RED-DB = factory-db;

my &get-recent-author's-posts'-titles = get-controller's-help("get-recent-author's-posts");

# Create the needed person with posts
my $author = factory-create "person", :PARS{ :10num-of-posts };

my @posts = get-recent-author's-posts'-titles $author.id, 3;

is-deeply @posts, ["Post title 10", "Post title 9", "Post title 8"];
```

DESCRIPTION
===========

RedFactory is ...

AUTHOR
======

    <fernandocorrea@gmail.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2021 

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

