use strict;
use warnings FATAL => 'all';

use Test::More tests => 16;
use Mozilla::Mechanize;
use URI::file;
use Mozilla::DOM;
use File::Temp qw(tempdir);

BEGIN { use_ok('Mozilla::PromptService') };

my $url = URI::file->new_abs("t/test.html")->as_string;

$ENV{HOME} = tempdir("/tmp/moz_mech_XXXXXX", CLEANUP => 1);

my $moz = Mozilla::Mechanize->new(quiet => 1, visible => 0);

my @_last_call;

is(Mozilla::PromptService::Register({
	DEFAULT => sub { @_last_call = @_; },
}), 1);

ok($moz->get($url));
is($moz->title, "Test-forms Page");

my $prev_uri = $moz->uri;
$moz->submit_form(
    form_name => 'form2',
    fields    => {
        dummy2 => 'filled',
        query  => 'text',
    }
);
is($moz->uri, "$prev_uri?dummy2=filled&query=text");
is($_last_call[0], 'ConfirmEx');

my @_confirm_ex;
@_last_call = ();

is(Mozilla::PromptService::Register({
	ConfirmEx => sub { @_confirm_ex = @_; },
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
is(scalar(@_confirm_ex), 3);

isa_ok($_confirm_ex[0], 'Mozilla::DOM::Window');
is($_confirm_ex[0]->GetTextZoom, 1);

ok($moz->get('javascript:alert("gee")'));
is($_last_call[0], 'Alert');

is(scalar(@_last_call), 4);
is($_last_call[3], "gee");

$moz->close();
