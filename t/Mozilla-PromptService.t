use strict;
use warnings FATAL => 'all';

use Test::More tests => 23;
use Mozilla::Mechanize;
use URI::file;
use Mozilla::DOM;
use Mozilla::ConsoleService;
use File::Temp qw(tempdir);

BEGIN { use_ok('Mozilla::PromptService') };

my $url = URI::file->new_abs("t/test.html")->as_string;

$ENV{HOME} = tempdir("/tmp/moz_mech_XXXXXX", CLEANUP => 1);

my @_cons_msgs;
my $moz = Mozilla::Mechanize->new(quiet => 1, visible => 0);
Mozilla::ConsoleService::Register(sub { push @_cons_msgs, shift(); });

my @_last_call;

is(Mozilla::PromptService::Register({
	DEFAULT => sub { @_last_call = @_; },
}), 1);

ok($moz->get($url));
is($moz->title, "Test-forms Page");

my $prev_uri = $moz->uri;
ok($moz->get('javascript:alert("gee")'));
is($_last_call[0], 'Alert');

my @_confirm_ex;
@_last_call = ();
my $_prompt_res = "AAA";

is(Mozilla::PromptService::Register({
	ConfirmEx => sub { @_confirm_ex = @_; },
	Prompt => sub { return $_prompt_res; },
	DEFAULT => sub { @_last_call = @_; },
}), 1);
$moz->submit_form(
    form_name => 'form2',
    fields    => {
        dummy2 => 'filled',
        query  => 'text',
    }
);
is($moz->uri, "$prev_uri?dummy2=filled&query=text");
is_deeply(\@_last_call, []);

our $PRO_VERSION;
do "t/version.pl";
SKIP: {
	skip "No submit prompt for xulrunner", 3 unless $PRO_VERSION < 1.9;
is(scalar(@_confirm_ex), 3);

isa_ok($_confirm_ex[0], 'Mozilla::DOM::Window');
is($_confirm_ex[0]->GetTextZoom, 1);
};

ok($moz->get('javascript:alert("gee")'));
is($_last_call[0], 'Alert');

is(scalar(@_last_call), 4);
is($_last_call[3], "gee");

ok($moz->get('javascript:alert(prompt("gee"))'));
is_deeply(\@_cons_msgs, []);
is($_last_call[0], 'Alert');
is($_last_call[3], "AAA");

undef $_prompt_res;
ok($moz->get('javascript:alert(prompt("gee"))'));
is($_last_call[0], 'Alert');
is($_last_call[3], "null");

$moz->close();
