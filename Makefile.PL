
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Amazon::S3Curl::PurePerl - Pure Perl s3 helper/downloader.",
  "AUTHOR" => "Samuel Kaufman <samuel.c.kaufman\@gmail.com>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Amazon-S3Curl-PurePerl",
  "EXE_FILES" => [],
  "LICENSE" => "gpl",
  "NAME" => "Amazon::S3Curl::PurePerl",
  "PREREQ_PM" => {
    "Digest::SHA::PurePerl" => "5.85",
    "File::Spec" => "3.40",
    "File::Temp" => "0.2301",
    "IPC::System::Simple" => "1.21",
    "Log::Contextual" => "0.006000",
    "Module::Runtime" => "0.013",
    "Moo" => "1.003000",
    "Test::More" => "0.98"
  },
  "TEST_REQUIRES" => {},
  "VERSION" => "0.051",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Digest::SHA::PurePerl" => "5.85",
  "File::Spec" => "3.40",
  "File::Temp" => "0.2301",
  "IPC::System::Simple" => "1.21",
  "Log::Contextual" => "0.006000",
  "Module::Runtime" => "0.013",
  "Moo" => "1.003000",
  "Test::More" => "0.98"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



