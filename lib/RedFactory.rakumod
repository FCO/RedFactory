use Red::Model;
use Red::Database;
use Red::Schema;
unit class RedFactory:ver<0.0.1>:auth<cpan:fco>;

my %cache{ Red::Model };
my %factory;
my %factory-counter{Str}      is default(0);
my %model-counter{Red::Model} is default(0);
my $global-counter = 0;

sub factory(Str $fname, &block?, Red::Model :$model) is export {
    if $*REDFACTORY {
        %factory{$fname} = my $o = $*REDFACTORY.^clone;
        {
            my $*REDFACTORY = $o;
            .($o) with &block
        }
    } else {
        ::?CLASS.new.^factory: $fname, &block, :$model
    }
}

sub trait($name, &block) is export {
    die "trait is only valid inside a factory" unless $*REDFACTORY;
    $*REDFACTORY.^add-trait: $name, &block
}

class Factory is Any {
    has $!d;
    has %!traits;

    has UInt $.counter-by-factory = 0;
    has UInt $.counter-by-model   = 0;
    has UInt $.global-counter     = 0;

    has %!PARS;

    method PAR(Str $name) is rw {
        %!PARS{ $name }
    }

    method ^attr($fac, $name)   { $fac.^attributes.first(*.name eq $name) }
    method ^data($fac)   is rw  { $fac.^attr('$!d').get_value: $fac }
    method ^traits($fac) is rw  { $fac.^attr('%!traits').get_value: $fac }
    method ^model($fac)  is rw  { $ }
    method ^clone($fac, *%pars) {
        my Factory $o = $fac.clone:
            |%pars,
            counter-by-factory => $fac!counter-by-factory,
            counter-by-model   => $fac!counter-by-model,
            global-counter     => $fac!global-counter,
        ;
        my $data = $o.^attr: '$!d';
        $data.set_value: $o, my % = |$data.get_value($o), |%pars;
        my $traits = $o.^attr: '%!traits';
        $traits.set_value: $o, my % = |$o.^traits;
        my $PARS = $o.^attr: '%!PARS';
        $PARS.set_value: $o, my % = |$PARS.get_value($o), |(%pars<PARS> // %());
        $o
    }
    method ^add-trait($fac, Str $name, &block) {
        my $traits = $fac.^attr: '%!traits';
        $traits.set_value: $fac, my % = |$traits.get_value($fac), $name => &block;
    }
    method ^PARS($fac)         { $fac.^attr('%!PARS').get_value($fac) }
    method !counter-by-factory { ++%factory-counter{ self.factory-name } }
    method !counter-by-model   { ++%model-counter{ self.^model } }
    method !global-counter     { ++$global-counter }
}

method ^factory($, Str $fname, &block, Red::Model :$model is copy) {
    if $model =:= Red::Model {
        require ::($fname);
        $model = ::($fname);
    }

    my Mu %data{ Attribute };
    my $name = $model.^name;
    my \t = %cache{ $model.^orig } // do {
        my \Type = Metamodel::ClassHOW.new.new_type: :name("{ $name }Factory");
        Type.^add_parent: Factory;
        Type.^add_attribute: Attribute.new: :name<$!factory-name>, :package(Type), :type(Str), :has_accessor;
        for $model.^attributes -> Attribute $attr {
            my $attr-name = $attr.name.substr(2);
            Type.^add_attribute: my $a = Attribute.new: :name($attr.name), :package(Type), :type($attr.type), :has_accessor;
            Type.^add_method: $attr-name, my method (\SELF:) is rw {
                Proxy.new:
                    FETCH => method {
                        my $val = $a.get_value: SELF;
                        get-value SELF, $val
                    },
                    STORE => method ($value) {
                        $a.set_value: SELF, SELF.^data{ $attr-name } = $value
                    },
                ;
            }
        }
        Type.^compose;
        Type.^model = $model;
        %cache{ $model.^orig } = Type;
    }

    %factory{$fname} = my $*REDFACTORY = t.new: |%data;
    $*REDFACTORY.^attr('$!factory-name').set_value: $*REDFACTORY, $fname;
    block $*REDFACTORY
}

method ^factories($) { %factory }

sub factory-args(|c) is export { RedFactory.args-for: |c }

multi method args-for(UInt $number, Str $fname, +@traits, *%pars --> Array()) {
    self.args-for($fname, |@traits, |%pars) xx $number
}

multi method args-for(Str $fname, +@traits, *%pars --> Hash()) {
    my $factory = %factory{$fname}.^clone: |%pars;
    for @traits -> Str $trait-name {
        with $factory.^traits{ $trait-name } -> &trait {
            trait $factory
        } else {
            die "Couldn't find trait '$trait-name' for factory '{ $factory.factory-name }'"
        }
    }
    my %meths := $factory.^methods.map(*.name).Set;
    my %data = |$factory.^data, |%pars;
    %data.kv.map: -> $k, $v {
        next if $k eq "PARS";
        $k => get-value $factory, $v
    },
}

sub factory-create(|c) is export { RedFactory.create: |c }

multi method create(Str $fname, +@traits, *%pars) {
    %factory{$fname}.^model.^create: |self.args-for: $fname, |@traits, |%pars
}

sub factory-new(|c) is export { RedFactory.new: |c }

multi method new(Str $fname, +@traits, *%pars) {
    %factory{$fname}.^model.new: |self.args-for: $fname, |@traits, |%pars
}

method schema {
    schema |%cache.keys
}

sub factory-db(|c) is export { RedFactory.database: |c }

method database {
    my $*RED-DB = database "SQLite";
    self.schema.drop.create;
    $*RED-DB
}

sub factory-run(|c) is export { RedFactory.run: |c }
method run(&block) {
    my $*RED-DB = self.database;
    block self
}

sub get-value(Factory $factory, $v) {
        do if $v ~~ Callable {
            my %PARS := $factory.^PARS<>;
            my %pars is Set = $v.signature.params.grep(*.named).map: *.name.substr: 1;
            $v.(|($factory if $v.count), |%PARS.grep({ %pars{ .key } }).Hash)
        } else {
            $v
        }
}

=begin pod

=head1 NAME

RedFactory - A factory for testing code using Red

=head1 SYNOPSIS

=begin code :lang<raku>

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

# Testing your imaginary controller helper

use Test;

my $*RED-DB = factory-db;

my &get-recent-author's-posts'-titles =
    get-controller's-help("get-recent-author's-posts'-titles");

# Create the needed person with posts
my $author = factory-create "person", :PARS{ :10num-of-posts };

my @posts = get-recent-author's-posts'-titles $author.id, 3;

is-deeply @posts, ["Post title 10", "Post title 9", "Post title 8"];

=end code

=head1 DESCRIPTION

RedFactory is a easier way of testing code that uses Red

=head1 AUTHOR

 <fernandocorrea@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2021 

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
