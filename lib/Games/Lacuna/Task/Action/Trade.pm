package Games::Lacuna::Task::Action::Trade;

use 5.010;
our $VERSION = $Games::Lacuna::Task::VERSION;
no if $] >= 5.017004, warnings => qw(experimental::smartmatch);

use Moose;
extends qw(Games::Lacuna::Task::Action);
with qw(Games::Lacuna::Task::Role::Ships
    Games::Lacuna::Task::Role::PlanetRun);

use Games::Lacuna::Task::Utils qw(parse_ship_type clean_name);

has 'trades' => (
    is              => 'rw',
    isa             => 'HashRef',
    required        => 1,
    documentation   => 'Automatic trades per planet [Required in config]',
);

sub description {
    return q[Add recurring trades to Trade Ministry];
}

sub process_planet {
    my ($self,$planet_stats) = @_;
    
    return
        unless defined $self->trades->{$planet_stats->{name}}
        || defined $self->trades->{$planet_stats->{id}}
        || defined $self->trades->{clean_name($planet_stats->{name})};
        
    # Get trade ministry
    my $tradeministry = $self->find_building($planet_stats->{id},'Trade');
    return 
        unless $tradeministry;
    
    # Get trade ministry
    my $tradeministry_object = $self->build_object($tradeministry);
    
    my $trades = $self->trades->{$planet_stats->{name}} || $self->trades->{$planet_stats->{id}};
    
    # Check if we have trades
    return 
        unless scalar @{$trades};
    
    # Get current trade
    my $trade_data = $self->paged_request(
        object  => $tradeministry_object,
        method  => 'view_my_market',
        total   => 'trade_count',
        data    => 'trades',
    )->{trades};
    
    my @current_trades = $self->_trade_serialize_response($trade_data);
    
    return
        if scalar @current_trades >= $tradeministry->{level};
    
    my ($stored_resources,$stored_plans,$stored_glyphs,);
    
    # Loop all trades
    TRADE:
    foreach my $trade (@{$trades}) {
        my @offer_data;
        my $trade_complete = 1;
        my $trade_identifier;
        my %trade_identifier_parts;
        
        
        # Check offers
        unless (defined $trade->{offers}
            && ref $trade->{offers} eq 'ARRAY') {
            $self->log('error','Invalid trade setting: Offers missing or invalid (%s)',$trade->{offers});
            next TRADE;
        }
        unless (defined $trade->{ask}
            && $trade->{ask} =~ m/^\d+(\.\d)?$/
            && $trade->{ask} > 0) {
            $self->log('error','Invalid trade setting: Ask missing or invalid (%s)',$trade->{ask});
            next TRADE;
        }
        
        # Build trade identifier
        foreach my $offer (@{$trade->{offers}}) {
            unless (defined $offer->{type}) {
                $self->log('error','Invalid trade setting: Offer type missing or invalid (%s)',$offer->{type});
                next TRADE;
            }
            $offer->{quantity} ||= 1;
            my $trade_identifier_part;
            if ($offer->{class} eq 'plan') {
                $offer->{level} //= 1;
                $offer->{extra_build_level} //= 0;
                $trade_identifier_part = $offer->{class}.':'.$offer->{type}.':'.$offer->{level};
                $trade_identifier_part .= '+'.$offer->{extra_build_level}
                    if $offer->{extra_build_level} > 0;
            } elsif ($offer->{class} eq 'ship') {
                $trade_identifier_part = $offer->{class}.':'.parse_ship_type($offer->{type});
            } else {
                $trade_identifier_part = $offer->{class}.':'.lc($offer->{type});
            }
            $trade_identifier_part = lc($trade_identifier_part);
            $trade_identifier_parts{$trade_identifier_part} = $offer->{quantity};
        }
        
        $trade_identifier = _trade_serialize($trade->{ask},%trade_identifier_parts);
        
        next TRADE
            if $trade_identifier ~~ \@current_trades;
        
        # Check offer items
        foreach my $offer (@{$trade->{offers}}) {
            
            given ($offer->{class}) {
                when('ship') {
                    my @avaliable_ships = $self->get_ships(
                        planet          => $planet_stats,
                        quantity        => $offer->{quantity},
                        type            => $offer->{type},
                        name_prefix     => 'Trade',
                    );
                    
                    if (scalar @avaliable_ships == $offer->{quantity}) {
                        foreach my $ship (@avaliable_ships) {
                            push (@offer_data,{
                                "type"      => "ship",
                                "ship_id"   => $ship,
                            });
                        }
                    } else {
                        $self->log('debug','Not enough %s ships available',$offer->{type});
                        $trade_complete = 0;
                    }
                }
                when ('plan') {
                    next
                        unless $trade_complete;
                    $stored_plans ||= $self->request(
                        object  => $tradeministry_object,
                        method  => 'get_plan_summary',
                    )->{plans};
                    
                    my $needed_quantity = $offer->{quantity};
                    PLAN:
                    foreach my $plan (@{$stored_plans}) {
                        if (lc($plan->{name}) eq lc($offer->{type})
                            && $plan->{level} == $offer->{level}
                            && $plan->{extra_build_level} == $offer->{extra_build_level}
                            && $plan->{quantity} >= $needed_quantity) {
                            push (@offer_data,{
                                "type"              => "plan",
                                "quantity"          => $needed_quantity,
                                "plan_type"         => $plan->{plan_type},
                                "level"             => $plan->{level},
                                "extra_build_level" => $plan->{extra_build_level},
                            });
                            $needed_quantity = 0;
                            last PLAN;
                        }
                    }
                    
                    unless ($needed_quantity == 0) {
                        $trade_complete = 0;
                        $self->log('debug','Not enough %s(%i+%i) plans available',$offer->{type},$offer->{level},$offer->{extra_build_level});
                    }
                }
                when ('glyph') {
                    next
                        unless $trade_complete;
                    $stored_glyphs ||= $self->request(
                        object  => $tradeministry_object,
                        method  => 'get_glyph_summary',
                    )->{glyphs};
                    
                    my $needed_quantity = $offer->{quantity};
                    GLYPH:                    
                    foreach my $glyph (@{$stored_glyphs}) {
                        if (lc($glyph->{type}) eq lc($offer->{type})
                            && $needed_quantity >= $glyph->{quantity}) {
                            push (@offer_data,{
                                "type"      => "glyph",
                                "quantity"  => $needed_quantity,
                                "name"      => $glyph->{name},
                            });
                            $needed_quantity = 0;
                            last GLYPH;
                        }
                    }
                    unless ($needed_quantity == 0) {
                        $trade_complete = 0;
                        $self->log('debug','Not enough %s glyphs available',$offer->{type});
                    }
                }
                when ('resource') {
                    next
                        unless $trade_complete;
                    $stored_resources ||= $self->request(
                        object  => $tradeministry_object,
                        method  => 'get_stored_resources',
                    )->{resources};
                    
                    unless (defined $stored_resources->{$offer->{type}}) {
                        $self->log('error','Invalid trade setting: Unknown resource type (%s)',$trade->{type});
                        next TRADE;
                    }
                    
                    if ($stored_resources->{$offer->{type}} > $offer->{quantity}) {
                        push (@offer_data,{
                            "type"      => $offer->{type},
                            "quantity"  => $offer->{quantity},
                        });
                    } else {
                        $self->log('debug','Not enough %s available',$offer->{type});
                        $trade_complete = 0;
                    }
                }
                when ('prisoner') {
                    $self->log('warn','Prisoner trade class not implemented yet');
                }
                default {
                    $self->log('error','Invalid trade setting: Unknown offer class (%s)',$_);
                    next TRADE;
                }
            }
        }
        
        # Add trade to market
        if ($trade_complete) {
            
            # Get trade ship
            my $trade_ships = $self->trade_ships($planet_stats->{id},\@offer_data);
            my @trade_ships = keys %{$trade_ships};
            
            next TRADE
                unless scalar @trade_ships == 1;
            
            my $response = $self->request(
                object  => $tradeministry_object,
                method  => 'add_to_market',
                params  => [ 
                    \@offer_data, 
                    $trade->{ask}, 
                    { ship_id => $trade_ships[0] } 
                ]
            );
            $self->log('notice','Adding trade on %s',$planet_stats->{name});
        }
    }
}

sub _trade_serialize {
    my ($ask,%offer) = @_;
    
    my @trade_identifier_parts = 
        map { lc($_).'='.$offer{$_} }
        grep { $offer{$_} > 0 }
        sort
        keys %offer;
        
    push(@trade_identifier_parts,'ask='.sprintf('%.1f',$ask));
    
    return join(';',@trade_identifier_parts);
}

sub _trade_serialize_response {
    my ($self,$trades) = @_;
    
    my @trade_identifiers;
    
    TRADES:
    foreach my $trade (@{$trades}) {
        my %trade_serialize;
        foreach my $offer (@{$trade->{offer}}) {
            my ($moniker,$quantity);
            $offer =~ s/^\s+//g;
            given ($offer) {
                when (/^(?<quantity>[0-9,]+)\s(?<type>\w+)$/) {
                    $moniker = 'resource:'.$+{type};
                    $quantity = $+{quantity};
                    $quantity =~ s/,//g;
                }
                when (/^(?<quantity>[0-9,]+)\s(?<type>\w+)\sglyph$/) {
                    $moniker = 'glyph:'.$+{type};
                    $quantity = $+{quantity};
                }
                when (/^(?<quantity>[0-9,]+)\s(?<type>[[:alpha:][:space:]]+)\s\(.+\)$/) {
                    $moniker = 'ship:'.parse_ship_type($+{type});
                    $quantity = $+{quantity};
                }
                when (/^(?<quantity>[0-9,]+)\s(?<type>[[:alnum:]'\[\]()[:space:]+]+)\s\((?<level>[^\)]+)\)\splan$/) {
                    $moniker = 'plan:'.lc($+{type}).':'.$+{level};
                    $quantity = $+{quantity};
                }
                when (/^(?<quantity>[0-9,]+)\sLevel\s(?<level>\d+)\sspy\snamed\s[^(]\(prisoner\)/) {
                    $moniker = 'prisoner:'.lc($+{level});
                    $quantity = $+{quantity};
                }
                default {
                    $self->log('warn',"Unkown offer: %s",$_);
                    next TRADES;
                }
            }
            $trade_serialize{$moniker} ||= 0;
            $trade_serialize{$moniker} += $quantity;
        }
        
        push(@trade_identifiers,_trade_serialize($trade->{ask},%trade_serialize));
    }
    
    return @trade_identifiers;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=pod

=encoding utf8

=head1 NAME

Games::Lacuna::Task::Action::Trade - Add recurring trades to Trade Ministry

=head1 DESCRIPTION

This task adds automatic recurring trades to the Trade Ministry. 

Usually you will need to set up automatic trades in your config file to 
use this action. The trade will only be created if you have the needed goods
on stock. Ships that are not on stock will be built.

trade:
  trades:
    "[PLANET NAME OR ID]":
      -
        ask: [ESSENTIA ASKING]
        offers:
          -
            class: "[ship|glyph|resource|plan|prisoner]" # required
            type: "[NAME/TYPE OF ITEM]" # required
            quantity: [QUANTITY] # default 1
            level: [PLAN LEVEL] # default 1
            extra_build_level: [PLAN EXTRA BUILD LEVEL] # default 0
          -
            ...
      -
        ...

Some example configurations:

trade:
  trades:
    "Home Sweet Home":
      -
        ask: 2
        offers:
          -
            class: "ship"
            type: "Galleon"
            quantity: 3
      -
        ask: 3
        offers:
          -
            class: "plan"
            type: "Geo Thermal Vent"
            level: 1
            extra_build_level: 5
          -
            class: "plan"
            type: "Vulcano"
            quantity: 3
            level: 1
          -
            class: "plan"
            type: "Natural Spring"
            level: 1
            quantity: 3
      -
        ask: 0.5
        offers:
          -
            class: "resouce"
            type: "trona"
            quantity: 100000
          -
            class: "resouce"
            type: "sulphur"
            quantity: 100000

=cut
