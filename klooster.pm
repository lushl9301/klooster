	package Klooster;
	use Lingua::Stem qw(stem);
	use PDL::LiteF;

	sub new
	{
		my $class = shift;
		my $self = { 
			threshold => 0.01,
			stop_words => import_stopwords(),
		};
		return bless $self, $class;
	}
	sub start 
	{
		my ($self,$seedword) = @_;
		$self->{'seedword'} = $seedword;
		my @docs = map{$_->[1]} @{ $self->{'all_docs'}->{$seedword} };
		my @original_docs = map{$_->[0]} @{ $self->{'all_docs'}->{$seedword} };
		
		$self->{'docs'} = \@docs;
		$self->{'original_docs'} = \@original_docs;
	
		$self->create_index;
		$self->vectorize_keywords;
	}
	
	#converts all the keywords to sparse vectors	
	sub vectorize_keywords
	{ 
		my $self = shift;
		my @return;
		foreach my $doc ( @{ $self->{'docs'} }) {
			my $vec = $self->make_vector( $doc );
			push @return, norm $vec;
		}
		$self->{'vectors'} = \@return;
	}
	
	sub create_index
	{
		my $self = shift;
		my %tokens;
		foreach my $doc ( @{ $self->{docs} } ) {
			my %words = $self->get_words( $doc );
			#count occurrences of all words 
			foreach( keys %words ) {
				$tokens{$_} += $words{$_};
			}
		}

		#give a numeric value to each word
		my %index;
		my @sorted_words = sort keys %tokens;
		@index{@sorted_words} = (1..$#sorted_words );
		$self->{'word_index'} = \%index;
		$self->{'word_count'} = keys %tokens;
	}
	
	#split words, remove stop words, stemming
	sub get_words {	
		my ( $self, $text ) = @_;
		my %doc_words;  
		my @words = 
					map { stem($_)->[0] }
					grep { !$self->{'stop_words'}->{$_} }
					split ' ', $text;
		do { $_++ } for @doc_words{@words};
		return %doc_words;
	}	
	
	#converts string to vectors
	sub make_vector {
		my ( $self, $doc ) = @_;
		my %words = $self->get_words( $doc );	
		my $vector = zeroes $self->{'word_count'};
		
		foreach my $w ( keys %words ) {
			my $value = $words{$w};
			my $offset = $self->{'word_index'}->{$w};
			index( $vector, $offset ) .= $value;
		}
		return $vector;
	}
	
	#search function
	sub search 
	{
		my ( $self, $query ) = @_;
		return if($query eq "EmptyKeywordType");
		my $vquery = norm $self->make_vector( $query );
		my $index = 0;
		my %results;
		
		foreach my $vector ( @{ $self->{'vectors'}  }) {
			
			#calculate distance between vectors and return if it's within the threshold
			my $cosine = cosine( $vector, $vquery );
			$results{$self->{'docs'}->[$index]} = $self->{'original_docs'}->[$index] if ($cosine > $self->{'threshold'});
			$index++;
		}
		
		return %results;
	}
	
	#cosine function to calculate the distance between vectors
	sub cosine {
		inner( shift, shift)->sclr;
	}
	
	#function to exclude seedword
	sub exclude_seedwords{
		my $class = shift;
		my($seedword,$keyword) = (shift,shift);
		#return if(! ($seedword | $keyword));
		my @return;
		my @keyword = split ' ', $keyword;
		my @seedword = split ' ',$seedword;
		foreach my $i (@keyword){
				next if grep {$_ eq $i} @seedword;
				push @return, $i;
			}
		return "EmptyKeywordType" unless(@return);
		join ' ', @return;
	}

	#import stopwords
	sub import_stopwords {
		my %stop_words = map { $_, 1} qw(a able about across after all almost also am among an and any are as at be because been but by can cannot could dear did do does either else ever every for from get got had has have he her hers him his how however i if in into is it its just least let like likely may me might most must my neither no nor not of off often on only or other our own rather said say says she should since so some than that the their them then there these they this tis to too twas us wants was we were what when where which while who whom why will with would yet you your);
		\%stop_words;
	}
	
	sub get_groups{
		my($self,$seedword) = @_;
		my @out;
		$self->start($seedword);
		$self->{'seedword'} = $seedword;
		foreach(@{$self->{docs}}){
			my %results = $self->search($_);
				next unless(keys %results);	
			my $group = [values %results];
			my $out = {$self->name_group([keys %results]) => 
											{	keywords => [@$group],
												seedword => [$seedword] 
											}};
			push @out ,$out if( $self->fingerprint($group) );
		}
		@out;
		
	}
	
	sub fingerprint{
		my ($self,$group) = @_;
		my @array = sort @$group;
		my $fp = "@array";
		return if($self->{'group_signatures'}->{$fp}++); #return false if exists
		return 1;
		
	}
	
	sub name_group{
		my ($self,$group) = @_;
		my $string = "@$group";		
		my %h;
		$h{$_}++ foreach(split ' ',$string);
		my @foo = (reverse sort { $h{$a} <=> $h{$b} } keys(%h));
		return $foo[0];
	}
}
