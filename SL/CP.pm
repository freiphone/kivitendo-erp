#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# Check and receipt printing payment module backend routines
# Number to text conversion routines are in
# locale/{countrycode}/Num2text
#
#======================================================================

package CP;
use SL::DBUtils;

use strict;

sub new {
  $main::lxdebug->enter_sub();

  my ($type, $countrycode) = @_;

  my $self = {};

  if ($countrycode) {
    if (-f "locale/$countrycode/Num2text") {
      require "locale/$countrycode/Num2text";
    } else {
      use SL::Num2text;
    }
  } else {
    use SL::Num2text;
  }

  $main::lxdebug->leave_sub();

  bless $self, $type;
}

sub paymentaccounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $ARAP = $form->{ARAP} eq "AR" ? "AR" : "AP";

  my $query =
    qq|SELECT accno, description, link | .
    qq|FROM chart | .
    qq|WHERE link LIKE ? |.
    qq|ORDER BY accno|;
  my $sth = prepare_execute_query($form, $dbh, $query, '%' . $ARAP . '%');

  $form->{PR}{ $form->{ARAP} } = ();
  $form->{PR}{"$form->{ARAP}_paid"} = ();

  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    foreach my $item (split(/:/, $ref->{link})) {
      if ($item eq $form->{ARAP}) {
        push(@{ $form->{PR}{ $form->{ARAP} } }, $ref);
      }
      if ($item eq "$form->{ARAP}_paid") {
        push(@{ $form->{PR}{"$form->{ARAP}_paid"} }, $ref);
      }
    }
  }
  $sth->finish;

  # get currencies and closedto
  $query = qq|SELECT curr, closedto FROM defaults|;
  ($form->{currencies}, $form->{closedto}) =
    selectrow_query($form, $dbh, $query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_openvc {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my $arap = ($form->{vc} eq 'customer') ? 'ar' : 'ap';
  my $vc = $form->{vc} eq "customer" ? "customer" : "vendor";
  my $query =
    qq|SELECT count(*) | .
    qq|FROM $vc ct, $arap a | .
    qq|WHERE (a.${vc}_id = ct.id) AND (a.amount != a.paid)|;
  my ($count) = selectrow_query($form, $dbh, $query);

  # build selection list
  if ($count < $myconfig->{vclimit}) {
    $query =
      qq|SELECT DISTINCT ct.id, ct.name | .
      qq|FROM $vc ct, $arap a | .
      qq|WHERE (a.${vc}_id = ct.id) AND (a.amount != a.paid) | .
      qq|ORDER BY ct.name|;
    $form->{"all_$form->{vc}"} = selectall_hashref_query($form, $dbh, $query);
  }

  if ($form->{ARAP} eq 'AR') {
    $query =
      qq|SELECT d.id, d.description | .
      qq|FROM department d | .
      qq|WHERE d.role = 'P' | .
      qq|ORDER BY 2|;
  } else {
    $query =
      qq|SELECT d.id, d.description | .
      qq|FROM department d | .
      qq|ORDER BY 2|;
  }
  $form->{all_departments} = selectall_hashref_query($form, $dbh, $query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_openinvoices {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $vc = $form->{vc} eq "customer" ? "customer" : "vendor";

  my $buysell = $form->{vc} eq 'customer' ? "buy" : "sell";
  my $arap = $form->{arap} eq "ar" ? "ar" : "ap";

  my $query =
     qq|SELECT a.id, a.invnumber, a.transdate, a.amount, a.paid, a.curr | .
     qq|FROM $arap a | .
     qq|WHERE (a.${vc}_id = ?) AND (COALESCE(a.curr, '') = ?) AND NOT (a.amount = a.paid)| .
     qq|ORDER BY a.id|;
  my $sth = prepare_execute_query($form, $dbh, $query,
                                  conv_i($form->{"${vc}_id"}),
                                  "$form->{currency}");

  $form->{PR} = [];
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {

    # if this is a foreign currency transaction get exchangerate
    $ref->{exchangerate} =
      $form->get_exchangerate($dbh, $ref->{curr}, $ref->{transdate}, $buysell)
      if ($form->{currency} ne $form->{defaultcurrency});
    push @{ $form->{PR} }, $ref;
  }

  $sth->finish;

  $query = <<SQL;
    SELECT COUNT(*)
    FROM $arap
    WHERE (${vc}_id = ?)
      AND (COALESCE(curr, '') <> ?)
      AND (amount <> paid)
SQL
  ($form->{openinvoices_other_currencies}) = selectfirst_array_query($form, $dbh, $query, conv_i($form->{"${vc}_id"}), "$form->{currency}");

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub process_payment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my $amount;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($paymentaccno) = split /--/, $form->{account};

  # if currency ne defaultcurrency update exchangerate
  if ($form->{currency} ne $form->{defaultcurrency}) {
    $form->{exchangerate} =
      $form->parse_amount($myconfig, $form->{exchangerate});

    if ($form->{vc} eq 'customer') {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{datepaid}, $form->{exchangerate}, 0);
    } else {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{datepaid}, 0, $form->{exchangerate});
    }
  } else {
    $form->{exchangerate} = 1;
  }

  my $query = qq|SELECT fxgain_accno_id, fxloss_accno_id FROM defaults|;
  my ($fxgain_accno_id, $fxloss_accno_id) = selectrow_query($form, $dbh, $query);

  my $buysell = $form->{vc} eq "customer" ? "buy" : "sell";
  my $arap = $form->{arap} eq "ar" ? "ar" : "ap";

  my $ml;
  my $where;

  if ($form->{ARAP} eq 'AR') {
    $ml    = 1;
    $where = qq| ((c.link = 'AR') OR (c.link LIKE 'AR:%')) |;
  } else {
    $ml    = -1;
    $where =
      qq| ((c.link = 'AP') OR | .
      qq|  (c.link LIKE '%:AP') OR | .
      qq|  (c.link LIKE '%:AP:%')) |;
  }

  my $paymentamount = $form->{amount};

  my $null;
  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;

  # query to retrieve paid amount
  $query =
    qq|SELECT a.paid FROM ar a | .
    qq|WHERE a.id = ? | .
    qq|FOR UPDATE|;
  my $pth = prepare_query($form, $dbh, $query);

  # go through line by line
  for my $i (1 .. $form->{rowcount}) {

    $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"});
    $form->{"due_$i"}  = $form->parse_amount($myconfig, $form->{"due_$i"});

    if ($form->{"checked_$i"} && $form->{"paid_$i"}) {
      $paymentamount = (($paymentamount * 1000) - ($form->{"paid_$i"} * 1000)) / 1000;

      # get exchangerate for original
      $query =
        qq|SELECT $buysell | .
        qq|FROM exchangerate e | .
        qq|JOIN ${arap} a ON (a.transdate = e.transdate) | .
        qq|WHERE (e.curr = ?) AND (a.id = ?)|;
      my ($exchangerate) =
        selectrow_query($form, $dbh, $query,
                        $form->{currency}, $form->{"id_$i"});

      $exchangerate = 1 unless $exchangerate;

      $query =
        qq|SELECT c.id | .
        qq|FROM chart c | .
        qq|JOIN acc_trans a ON (a.chart_id = c.id) | .
        qq|WHERE $where | .
        qq|AND (a.trans_id = ?)|;
      my ($id) = selectrow_query($form, $dbh, $query, $form->{"id_$i"});

      $amount = $form->round_amount($form->{"paid_$i"} * $exchangerate, 2);

      # add AR/AP
      $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, transdate, amount) | .
        qq|VALUES (?, ?, ?, ?)|;
      do_query($form, $dbh, $query, $form->{"id_$i"}, $id,
               conv_date($form->{datepaid}), $amount * $ml);

      # add payment
      $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, transdate, amount, | .
        qq|                       source, memo) | .
        qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, ?)|;
      my @values = (conv_i($form->{"id_$i"}), $paymentaccno,
                    conv_date($form->{datepaid}),
                    $form->{"paid_$i"} * $ml * -1, $form->{source},
                    $form->{memo});
      do_query($form, $dbh, $query, @values);

      # add exchangerate difference if currency ne defaultcurrency
      $amount = $form->round_amount($form->{"paid_$i"} * ($form->{exchangerate} - 1),
                            2);
      if ($amount != 0) {

        # exchangerate difference
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, transdate, amount, | .
          qq|                       cleared, fx_transaction) | .
          qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, ?)|;
        @values = (conv_i($form->{"id_$i"}), $paymentaccno,
                   conv_date($form->{datepaid}), ($amount * $ml * -1), '0',
                   '1');
        do_query($form, $dbh, $query, @values);

        # gain/loss

        $amount =
          $form->round_amount($form->{"paid_$i"} *
                              ($exchangerate - $form->{exchangerate}), 2);
        if ($amount != 0) {
          my $accno_id = ($amount < 0) ? $fxgain_accno_id : $fxloss_accno_id;
          $query =
            qq|INSERT INTO acc_trans (trans_id, chart_id, transdate, | .
            qq|                       amount, cleared, fx_transaction) | .
            qq|VALUES (?, ?, ?, ?, ?, ?)|;
          @values = (conv_i($form->{"id_$i"}), $accno_id,
                     conv_date($form->{datepaid}), $amount * $ml * -1, '0',
                     '1');
          do_query($form, $dbh, $query, @values);
        }
      }

      $form->{"paid_$i"} =
        $form->round_amount($form->{"paid_$i"} * $exchangerate, 2);
      $pth->execute($form->{"id_$i"}) || $form->dberror;
      ($amount) = $pth->fetchrow_array;
      $pth->finish;

      $amount += $form->{"paid_$i"};

      my $paid;
      # BUG 324
      if ($form->{arap} eq 'ap') {
        $paid = "paid = paid + $amount";
      } else {
        $paid = "paid = $amount";
      }

      # update AR/AP transaction
      $query = qq|UPDATE $arap SET $paid, datepaid = ? WHERE id = ?|;
      @values = (conv_date($form->{datepaid}), conv_i($form->{"id_$i"}));
      do_query($form, $dbh, $query, @values);
      # saving the history
      $form->{id} = $form->{"id_$i"};
      if(!exists $form->{addition}) {
        $form->{snumbers} = qq|invnumber_| . $form->{"invnumber_$i"};
        $form->{addition} = "POSTED";
        $form->save_history($form->dbconnect($myconfig));
      }
      # /saving the history
    }
  }

  my $rc;
  if ($form->round_amount($paymentamount, 2) < 0) {
		# Hier werden negativen Zahlungseingänge abgefangen
		# Besser: in Oberfläche schon prüfen
		# Zahlungsein- und ausgänge sind immer positiv
    $dbh->rollback;
    $rc = 0;
  }
  if ($form->round_amount($paymentamount, 2) == 0) {
    $rc = $dbh->commit;
  }

  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

1;

