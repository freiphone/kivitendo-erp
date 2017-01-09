package SL::PriceSource::CustomPrice;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::PriceSource::Price;
use SL::Locale::String;
use SL::DB::PartCustomerPrice;
# use List::UtilsBy qw(min_by max_by);

sub name { 'customprice' }

sub description { t8('Customer specific Price') }

sub available_prices {
  my ($self, %params) = @_;

  return () if !$self->part;
  return () if !$self->record->is_sales;

  map { $self->make_price_from_customprice($_) }
  grep { $_->customer_id == $self->record->customer_id }
  $self->part->customprices;
}

sub available_discounts { }

sub price_from_source {
  my ($self, $source, $spec) = @_;

  my $customprice = SL::DB::Manager::PartCustomerPrices->find_by(id => $spec);

  return $self->make_price_from_customprice($customprice);

}

sub best_price {
  my ($self, %params) = @_;

  return () if !$self->record->is_sales;

#  min_by { $_->price } $self->available_prices;
#  max_by { $_->price } $self->available_prices;
  &available_prices;

}

sub best_discount { }

sub make_price_from_customprice {
  my ($self, $customprice) = @_;

  return SL::PriceSource::Price->new(
    price        => $customprice->price,
    spec         => $customprice->id,
    description  => $customprice->customer_partnumber,
    price_source => $self,
  );
}


1;
