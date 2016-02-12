package SL::Controller::Assembly;

use strict;

use parent qw(SL::Controller::Base);

use List::Util qw(first min);

use SL::Controller::Helper::ReportGenerator;
use SL::DB::Helper::Paginated ();
use SL::DB::Assembly;
use SL::Locale::String;
use SL::IC;

use Rose::Object::MakeMethods::Generic
(
  scalar => [qw(object object_id level maxlevel wantlevel rowcount first_nr last_nr levels direction)],
);

__PACKAGE__->run_before('check_object_params', only => [qw(ajax_listcomponents ajax_listassemblies)]);

#--- 4 locale ---#
# $main::locale->text('Structural Parts List')
# $main::locale->text('Used In Assemblies')
#
# render('assembly/listassemblies');
# render('assembly/listcomponents');
#
# actions
#

sub action_export_listcomponents {
  my ($self) = @_;
  $main::lxdebug->enter_sub();
  if ($::form->{report_generator_output_format} eq 'HTML') {
    $self->redirect_back();
  } else {
    # no font less than 10 pt
    # better to implement with default "UserPreferences::Favorites"
    if ($::form->{report_generator_pdf_options_font_size} &&
        ($::form->{report_generator_pdf_options_font_size} * 1) < 10 ) {
      $::form->{report_generator_pdf_options_font_size} = 10;
    }
    $self->check_object_params();
    $self->action_ajax_listcomponents();
  }
  $main::lxdebug->leave_sub();
}

sub action_ajax_listcomponents {
  my ($self) = @_;
  $main::lxdebug->enter_sub();

  my %args = (
    with_objects => ['part'],
    where        => [id => $self->object_id, parts_id => { ne => undef }],
    sort_by      => 'assembly_id',
  );

  $self->wantlevel($::form->{maxlevel} ? $::form->{maxlevel} : 25);
  $self->prepare_report('export_listcomponents', 'Structural Parts List', 'listcomponents');

  my $items = SL::DB::Manager::Assembly->get_all(%args);
  $self->level(0);
  $self->maxlevel(0);
  $self->rowcount(0);
  $self->firstrow;
  $self->direction(1);

  foreach my $entry (@{$items}) {
    $self->addComponent($entry, 0, 1);
  }

  #$self->prepare_paginate('listcomponents');

  if ($::form->{report_generator_output_format} eq 'HTML') {
    my @levels = (1 .. $self->maxlevel);
    $self->levels(\@levels);
    $self->wantlevel($self->maxlevel) if $self->wantlevel > $self->maxlevel;
    my $bottom = $::form->parse_html_template('assembly/select_level', { SELF => $self });
    $self->{report}->set_options(raw_bottom_info_text => $bottom,);

    my $html = $self->{report}->generate_html_content(%{ { no_layout => 1 } });
    $self->render(\$html, { layout => 0, process => 0 });
  }
  else {
    $self->{report}->generate_with_headers();
  }
  $main::lxdebug->leave_sub();
}

sub action_export_listassemblies {
  my ($self) = @_;
  $main::lxdebug->enter_sub();
  if ($::form->{report_generator_output_format} eq 'HTML') {
      $self->redirect_back();
  } else {
    # no font less than 10 pt
    # better to implement with default "UserPreferences::Favorites"
    if ($::form->{report_generator_pdf_options_font_size} &&
        ($::form->{report_generator_pdf_options_font_size} * 1) < 10 ) {
      $::form->{report_generator_pdf_options_font_size} = 10;
    }
    $self->check_object_params();
    $self->action_ajax_listassemblies();
  }
  $main::lxdebug->leave_sub();
}

sub action_ajax_listassemblies {
  my ($self) = @_;
  $main::lxdebug->enter_sub();

  my %args = (
    with_objects => ['part'],
    where        => [parts_id => $self->object_id, id => { ne => undef }],
    sort_by      => 'assembly_id',
  );

  $self->wantlevel($::form->{maxlevel} ? $::form->{maxlevel} : 25);
  $self->prepare_report('export_listassemblies', 'Used In Assemblies', 'listassemblies');

  my $items = SL::DB::Manager::Assembly->get_all(%args);
  $self->level(0);
  $self->maxlevel(0);
  $self->rowcount(0);
  $self->firstrow;
  $self->direction(0);
  foreach my $entry (@{$items}) {
    $self->addComponent($entry, 1, 1);
  }

  #$self->prepare_paginate('listassemblies');

  if ($::form->{report_generator_output_format} eq 'HTML') {
    my @levels = (1 .. $self->maxlevel);
    $self->levels(\@levels);
    $self->wantlevel($self->maxlevel) if $self->wantlevel > $self->maxlevel;
    my $bottom = $::form->parse_html_template('assembly/select_level', { SELF => $self });
    $self->{report}->set_options(raw_bottom_info_text => $bottom,);

    my $html = $self->{report}->generate_html_content(%{ { no_layout => 1 } });
    $self->render(\$html, { layout => 0, process => 0 });
  }
  else {
    $self->{report}->generate_with_headers();
  }
  $main::lxdebug->leave_sub();
}

#
# Helpers
#
sub redirect_back {
  my ($self) = @_;
  ## back button
  my @url_params = (
    controller => 'controller.pl',
    action     => 'Part/edit',
    'part.id'  => $::form->{object_id},
  );
  if ($::form->{callback}) {
    push(@url_params, callback => $::form->{callback});
  }
  $self->redirect_to(@url_params);
}

sub prepare_paginate {
  my ($self, $action) = @_;
  $main::lxdebug->enter_sub();

  my $num_rows = $self->rowcount;
  my $page     = $::form->{page} || 1;
  my $pages    = {};
  $pages->{per_page} = $::form->{per_page} || 20;
  $pages->{max} = SL::DB::Helper::Paginated::ceil($num_rows, $pages->{per_page}) || 1;
  $pages->{page} = $page < 1 ? 1 : $page > $pages->{max} ? $pages->{max} : $page;

  #$::lxdebug->message(LXDebug->DEBUG2(),"numrows=".$num_rows." perpage=".$pages->{per_page}." max=".$pages->{max}." page=".$pages->{page});
  $pages->{common} = [grep { $_->{visible} } @{ SL::DB::Helper::Paginated::make_common_pages($pages->{page}, $pages->{max}) }];
  $self->{pages} = $pages;

  $self->{base_url} = $self->url_for(action => 'ajax_' . $action, object_id => $self->object_id);
  my $bottom = $::form->parse_html_template('assembly/report_bottom', { SELF => $self });

  #$::lxdebug->message(LXDebug->DEBUG2(),"bottom=".$bottom );
  $self->{report}->set_options(raw_bottom_info_text => $bottom,);
  $main::lxdebug->leave_sub();
}

sub firstrow {
  my ($self) = @_;
  return if $::form->{report_generator_output_format} eq 'HTML';
  return if $::form->{report_generator_output_format} eq 'PDF';

  my $row = {};
  $row->{pos}->{data}   = '';
  $row->{level}->{data} = '';
  $row->{partn}->{data} = $self->object->partnumber;
  $row->{partt}->{data} = $::request->presenter->typeclass_abbreviation($self->object);
  $row->{desc}->{data}  = $self->object->description;
  $row->{qty}->{data}   = '';
  $row->{unit}->{data}  = '';
  $self->{report}->add_data($row);
}

sub addComponent {
  my ($self, $entry, $listassemblies, $allrows) = @_;
  $::lxdebug->message(LXDebug->DEBUG2(), "addComponent" . $listassemblies . " level=" . $self->level . " id=" . $entry->id . " parts_id=" . $entry->parts_id);
  return if $self->level > 20;    ##erst mal notbremse  $self->level($self->level+1);

  $self->level($self->level + 1);
  $self->maxlevel($self->level) if $self->maxlevel < $self->level;

  my %args = (
    with_objects => ['assembly_part', 'part'],
    where   => [id => $entry->parts_id, parts_id => { ne => undef }],
    sort_by => 'assembly_id',
  );
  $args{where} = [parts_id => $entry->id, id => { ne => undef }] if $listassemblies;
  if ($self->level <= $self->wantlevel && ($allrows || ($self->rowcount >= $self->first_nr && $self->rowcount < $self->last_nr))) {
    my $row = {};
    $row->{pos}->{data} = $self->rowcount + 1;
    $row->{level}->{data} = ('-' x ($self->level)) . $self->level;
    if ($listassemblies) {
      if ($entry->assembly_part) {
        $row->{partn}->{data}  = $entry->assembly_part->partnumber;
        $row->{notice}->{data} = $entry->notice;
        $row->{partt}->{data}  = $::request->presenter->typeclass_abbreviation($entry->part);
        $row->{desc}->{data}   = $entry->assembly_part->description;
        $row->{unit}->{data}   = $entry->assembly_part->unit;
      }
    }
    else {
      if ($entry->part) {
        $row->{partn}->{data}  = $entry->part->partnumber;
        $row->{notice}->{data} = $entry->notice;
        $row->{partt}->{data}  = $::request->presenter->typeclass_abbreviation($entry->part);
        $row->{desc}->{data}   = $entry->part->description;
        $row->{unit}->{data}   = $entry->part->unit;
      }
    }
    $row->{partn}->{link} = $self->link_to($listassemblies, $listassemblies ? $entry->id : $entry->parts_id);
    $row->{qty}->{data} = $::form->format_amount(\%::myconfig, $entry->qty);
    $self->{report}->add_data($row);
    $self->rowcount($self->rowcount + 1);
  }
  my $subitems = SL::DB::Manager::Assembly->get_all(%args);
  my $subcount = scalar(@{$subitems});
  foreach my $subentry (@{$subitems}) {
    $::lxdebug->message(LXDebug->DEBUG2(), "addComponent call for id=" . $subentry->id . " parts_id=" . $subentry->parts_id);
    $self->addComponent($subentry, $listassemblies, $allrows);
  }
  $self->level($self->level - 1);
  $::lxdebug->message(LXDebug->DEBUG2(), "addComponent returns level=" . $self->level . " rowcount=" . $self->rowcount);
}

sub prepare_report {
  my ($self, $nextsub, $title, $target) = @_;

  my $locale = $main::locale;
  my $report = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns = qw(pos level notice partn partt desc qty unit);

  my %column_defs = (
    'pos'    => { text => $locale->text('Position')        , visible => 1, width => '10', },
    'level'  => { text => $locale->text('Level')           , visible => ($self->wantlevel > 1 ? 1 : 0), width => '10', },
    'notice' => { text => $locale->text('Notice')          , visible => 1, },
    'partn'  => { text => $locale->text('Part Number')     , visible => 1, },
    'partt'  => { text => $locale->text('Type')            , visible => 1, width => '10', },
    'desc'   => { text => $locale->text('Part Description'), visible => 1, },
    'qty'    => { text => $locale->text('Qty')             , visible => 1, },
    'unit'   => { text => $locale->text('Unit')            , visible => 1, width => '10', },
  );

  $title = $::locale->text($title);
  $title .= ' ' . $::locale->text('for partnumber') . ' ' . $self->object->partnumber if $::form->{report_generator_output_format} ne 'HTML';

  $title .= ($self->object->drawing) ? ' -- ' . $locale->text('Drawing') . ': ' . $self->object->drawing : '';
  $self->{targetid} = '#' . $target;

  if ($::form->{report_generator_output_format} eq 'PDF') {
    my @custom_headers = ();

    # heading 1:
    push @custom_headers, [
      { 'text' => '   ' },
      { 'text' => $self->object->description, 'colspan' => ($self->wantlevel > 1 ? 5 : 4), 'align' => 'center' },
      { 'text' => '   ' },
    ];

    # heading 2:
    my @line_2 = ();
    map { push @line_2, $column_defs{$_} } grep { $column_defs{$_}->{visible} } @columns;
    push @custom_headers, [@line_2];

    $report->set_custom_headers(@custom_headers);
  }
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_options(allow_pdf_export => 1, allow_csv_export => 1, controller_class => 'Assembly');
  $report->set_sort_indicator($self->{sort_by}, $self->{sort_dir});
  $report->set_export_options($nextsub, qw(object_id callback maxlevel wantlevel));
  $report->set_options(
    output_format => 'HTML',
    title         => $title,
    html_template => 'assembly/' . $target,
  );
  $report->set_options_from_form;
  if ( $::form->{report_generator_output_format} eq 'PDF') {
     $report->set_options(
        top_info_text => $self->object->intnotes,
     );
  }
  # manual paginating
  # my $page = $::form->{page} || 1;
  # my $pages = {};
  # $pages->{per_page}        = $::form->{per_page} || 20;
  # $self->{pages} = $pages;
  # $self->first_nr(($page - 1) * $pages->{per_page});
  # $self->last_nr($self->first_nr + $pages->{per_page});
  $::form->{report_generator_output_format} = 'HTML' if !$::form->{report_generator_output_format};
}

sub link_to {
  my ($self, $listassemblies, $object, %params) = @_;

  return unless $object;
  my $action   = $params{action} || 'edit';
  my $cb       = '';
  my $tabindex = 1 + $listassemblies;

  #  $tabindex++ if $::instance_conf->get_doc_attachments;
  if ($::form->{callback}) {
    $cb = '&callback=' . $::form->escape($::form->{callback});
  }
  return "ic.pl?action=$action&id=$object" . $cb . "&ui_tab=" . $tabindex;
}

sub check_object_params {
  my ($self) = @_;
  $main::lxdebug->enter_sub();

  my $id = $::form->{object_id} + 0;

  if (!$id) {
    return 0;
  }
  $self->object_id($id);
  $self->object(SL::DB::Part->new(id => $self->object_id)->load || die "Record not found");
  $self->level(0);

  $main::lxdebug->leave_sub();
  return 1;

}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Assembly - Assembly controller

=head1 SYNOPSIS

# The actions are used in the Part Controller as extra tabs:

=begin text

    <a href="controller.pl?action=Assembly/ajax_listcomponents&object_id=[% HTML.url(SELF.part.id) %]"></a>

    <a href="controller.pl?action=Assembly/ajax_listassemblies&object_id=[% HTML.url(SELF.part.id) %]"></a>

    .

=end text

=head1 DESCRIPTION

Controller for displaying assembly tree of one assembly and
displaying reverse tree of an article. This is displayed
in two extra tabs of an article.
The first tab is only for assemblies, the second also for parts and services

=head1 URL ACTIONS

=over 4

=item C<action_ajax_listcomponents>

All direct and indirect depending components of one assembly are listed.
Ich row has the columns position, level, partnumber, part_type and part_classification,
description, notice, quantity and unit.

The level started at level 1 for the direct used components, the level 2 and up to level 25 (as limit)
are indirect components (childs form childs ...).
Also a '-' is displayed vor each lvel to see the tree like

=begin text

        -1

        --2

        ---3

        --2

        ---3

        ----4

        ----4

        -1

        --2

=end text

=item C<action_export_listcomponents>

This is the action to export a PDF or CSV Report  of a component list or go back to HTML.

=item C<action_ajax_listassemblies>

All direct and indirect used assemblies are listed. This is a revert list to the component list.
Each row has the same columns like the assembly tree.

=item C<action_export_listassemblies>

This is the action to export a PDF or CSV Report of a used assembly list or go back to HTML.

=back

=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>

=cut
