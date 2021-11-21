[![Actions Status](https://github.com/FCO/RedFactory/workflows/test/badge.svg)](https://github.com/FCO/RedFactory/actions)

NAME
====

RedFactory - A factory for testing code using Red

SYNOPSIS
========

```raku
use Test;
use Red;
use RedFactory;

model Person {
   has UInt    $.id          is serial;
   has Str     $.first-name  is column;
   has Str     $.last-name   is column;
   has Str     $.email       is column;
   has Instant $.disabled-at is column{ :nullable };
}

factory "person", :model(Person), {

   .first-name = "john";
   .last-name  = "doe";
   .email      = { "{ .first-name }{ .PAR("number") // .counter-by-model }@domain.com" }

   trait "disabled", {
      .disabled-at = now
   }
}

RedFactory.run: {

   given .create: "person" {
    is .first-name, "john";
    is .last-name,  "doe";
    is .email,      "john1@domain.com";
   }

   given .create: "person", :first-name<peter>, :last-name<parker> {
    is .first-name, "peter";
    is .last-name,  "parker";
    is .email,      "peter2@domain.com";
   }

   given .create: "person", :email<bla@ble.com> {
    is .first-name, "john";
    is .last-name,  "doe";
    is .email,      "bla@ble.com";
   }

   given .create: "person", "disabled" {
    is .first-name, "john";
    is .last-name,  "doe";
    is .email,      "john4@domain.com";
    ok .disabled-at;
   }

   given .create: "person", :PARS{ :42number } {
    is .first-name, "john";
    is .last-name,  "doe";
    is .email,      "john42@domain.com";
   }
}
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

