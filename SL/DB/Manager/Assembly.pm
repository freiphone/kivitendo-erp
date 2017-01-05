package SL::DB::Manager::Assembly;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Filtered;
use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Assembly' }

__PACKAGE__->make_manager_methods;

sub default_objects_per_page { 20 }

1;
