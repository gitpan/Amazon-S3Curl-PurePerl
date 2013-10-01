package Amazon::S3Curl::PurePerl;
#ABSTRACT: Amazon::S3Curl::PurePerl - Pure Perl s3 helper/downloader.
use strict;
use warnings FATAL => 'all';
use Module::Runtime qw[ require_module ];

our $VERSION = "0.02";
$VERSION = eval $VERSION;

#For instances when you want to use s3, but don't want to install anything. ( and you have curl )
#Amazon S3 Authentication Tool for Curl
#Copyright 2006-2010 Amazon.com, Inc. or its affiliates. All Rights Reserved. 
use Moo;
use POSIX;
use File::Spec;
use Log::Contextual qw[ :log :dlog set_logger ];
use Log::Contextual::SimpleLogger;
use Digest::SHA::PurePerl;
use MIME::Base64 qw(encode_base64);
use IPC::System::Simple qw[ capture ];
our $DIGEST_HMAC;
BEGIN {
    eval {
        require_module("Digest::HMAC");
        $DIGEST_HMAC = "Digest::HMAC";
    };
    if ($@) {    #They dont have Digest::HMAC, use our packaged alternative
        $DIGEST_HMAC = "Amazon::S3Curl::PurePerl::Digest::HMAC";
        require_module($DIGEST_HMAC);
    }
};


set_logger(
    Log::Contextual::SimpleLogger->new(
        {
            levels_upto => 'debug'
        } ) );


has curl => (
    is      => 'ro',
    default => sub { 'curl' }    #maybe your curl isnt in path?
);

for (
    qw[
    aws_access_key
    aws_secret_key
    url
    ] )
{
    has $_ => (
        is       => 'ro',
        required => 1,
    );

}

has local_file => ( 
    is => 'ro',
    required => 1,
    predicate => 1,
);

has static_http_date => (
    is => 'ro',
    required => 0,
);

has http_date => (
    is => 'lazy',
    clearer => 1,
);

sub _build_http_date {
    POSIX::strftime( "%a, %d %b %Y %H:%M:%S +0000", gmtime );
}

sub _req {
    my ( $self, $method, $url ) = @_;
    die "method required" unless $method;
    $url ||= $self->url;
    my $resource = $url;
    my $to_sign  = $url;
    $resource = "http://s3.amazonaws.com" . $resource;
    my $keyId       = $self->aws_access_key;
    $self->clear_http_date;
    my $httpDate    = $self->static_http_date || $self->http_date;
    my $contentMD5  = "";
    my $contentType = "";
    my $xamzHeadersToSign = "";
    my $stringToSign      = join( "\n" =>
          ( $method, $contentMD5, $contentType, $httpDate, "$xamzHeadersToSign$to_sign" ) );
    my $hmac =
      $DIGEST_HMAC->new( $self->aws_secret_key, "Digest::SHA::PurePerl",
        64 );
    $hmac->add($stringToSign);
    my $signature = encode_base64( $hmac->digest, "" );
    return [
        $self->curl,
        -H => "Date: $httpDate",
        -H => "Authorization: AWS $keyId:$signature",
        -H => "content-type: $contentType",
        "-L",
        "-f",
        $resource,
    ];
}




sub download_cmd {
    my ($self) = @_;
    my $args = $self->_req('GET');
    push @$args, ( "-o", $self->local_file );
    return $args;
}

sub upload_cmd {
    my ($self) = @_;
    my $url = $self->url;
    #trailing slash for upload means curl will plop on the filename at the end, ruining the hash signature.
    if ( $url =~ m|/$| ) {
        my $file_name = ( File::Spec->splitpath( $self->local_file ) )[-1];
        $url .= $file_name;
    }
    my $args = $self->_req('PUT',$url);
    splice( @$args, $#$args, 0, "-T", $self->local_file );
    return $args;
}

sub delete_cmd {
    my $args = shift->_req('DELETE');
    splice( @$args, $#$args, 0, -X  => 'DELETE' );
    return $args;
}

sub _exec {
    my($self,$method) = @_;
    my $meth = $method."_cmd";
    die "cannot $meth" unless $self->can($meth);
    my $args = $self->$meth;
    log_info { "running " . join( " ", @_ ) } @$args;
    capture(@$args);
    return 1;
}

sub download {
    return shift->_exec("download");
}

sub upload {
    return shift->_exec("upload");
}

sub delete {
    return shift->_exec("delete");
}

sub _local_file_required {
    my $method = shift;
    sub {
        die "parameter local_file required for $method"
          unless shift->local_file;
    };
}

before download => _local_file_required('download');
before upload => _local_file_required('upload');
1;
__END__

=head1 NAME

Amazon::S3Curl::PurePerl - Pure Perl s3 helper/downloader.

=head1 VERSION

version 0.02

=head1 DESCRIPTION

This software is designed to run in low dependency situations. 
You need curl, and you need perl ( If you are on linux, you probably have perl whether you know it or not ).

Maybe you're bootstrapping a system from s3,
or downloading software to a host where you can't/don't want to install anything.

=head1 SYNOPSIS

    my $s3curl = Amazon::S3Curl::PurePerl->new({
            aws_access_key => $ENV{AWS_ACCESS_KEY},
            aws_secret_key => $ENV{AWS_SECRET_KEY},
            local_file     => "/tmp/myapp.tgz",
            url            => "/mybootstrap-files/myapp.tgz"
    });
    $s3curl->download;
    
Using L<Object::Remote>:
    
    use Object::Remote;
    my $conn = Object::Remote->connect("webserver-3");

    my $s3_downloader = Amazon::S3Curl::PurePerl->new::on(
        $conn,
        {
            aws_access_key => $ENV{AWS_ACCESS_KEY},
            aws_secret_key => $ENV{AWS_SECRET_KEY},
            local_file     => "/tmp/myapp.tgz",
            url            => "/mybootstrap-files/myapp.tgz"
        } );

    $s3_downloader->download;

=head1 PARAMETERS

=over

=item aws_access_key ( required )

=item aws_secret_key ( required )

=item url ( required )

This is the (url to download|upload to|delete).
It should be a relative path with the bucket name, and whatever pseudopaths you want.

For upload:
Left with a trailing slash, it'll DWYM, curl style.

=item local_file

This is the (path to download to|file to upload).

=back


=head1 METHODS

=head2 new

Constructor, provided by Moo.


=head2 download

    $s3curl->download;
    
download url to local_file.

=head2 upload

    $s3curl->upload;
    
Upload local_file to url.

=head2 delete

    $s3curl->delete;
    
Delete url.

=head2 delete_cmd

=head2 download_cmd

=head2 upload_cmd

Just get the command to execute, don't actually execute it:
    my $cmd = $s3curl->download_cmd;
    system(@$cmd);

=head1 LICENSE

This library is free software and may be distributed under the same terms as perl itself.

=head1 AUTHOR AND CONTRIBUTORS

This distribution was 
adapted by Samuel Kaufman L<skaufman@cpan.org> from the L<Amazon S3 Authentication Tool for Curl|http://aws.amazon.com/code/128>

   Amazon S3 Authentication Tool for Curl
   Copyright 2006-2010 Amazon.com, Inc. or its affiliates. All Rights Reserved.
