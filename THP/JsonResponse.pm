package THP::JsonResponse;

use strict ;
use warnings;

use HTTP::Tiny;
use JSON;
use HTTP::Request::Common qw(GET POST DELETE);
use LWP::UserAgent;
use Data::Dumper;

my $http = HTTP::Tiny->new();

sub get_Json_response { # it returns the json response given the endpoint as param, it returns an array reference that contains hash references . If response not successful it returns 0
    my $url = shift; 
    my $response = $http->get($url);
#    print "getting $url ...\n"; #for logging (check eHive log functionality)
    my $json;
    my $json_aref; # array ref with hash references with the json stanzas

    my ($status, $reason) = ($response->{status}, $response->{reason}); #LWP perl library for dealing with http

    if($response->{success}) { 
	$json=$response->{content};     
	$json_aref = decode_json($json); # it returns an array reference with hash references (JSON module)
	return ($json_aref);
    }
    else {
	die "problem getting response from API url $url\nstatus:\n$response->{status}\nresponse:\n$response->{reason}\n";
    }
}


sub registry_login {

    my ($server, $user, $pass) = @_;
    my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });

    #log in
    my $request = GET("$server/api/login");
    $request->headers->authorization_basic($user, $pass);

    my $response = $ua->request($request);
    my $auth_token;
    if ($response->is_success) {
	$auth_token = from_json($response->content)->{auth_token};
	print "Logged in [$auth_token]\n" if $auth_token;
    } else {
	die sprintf "Couldn't login: %s [%d]", $response->content, $response->code;
    }

    return $auth_token;

}


sub delete_track {

    my ($server, $user, $auth_token,$study_id) = @_;
    my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
#    my $request = DELETE("$server/api/trackhub/$study_id");
    my $request = GET("$server/api/trackhub/$study_id");
    $request->headers->header(user       => $user);
    $request->headers->header(auth_token => $auth_token);
    my $response = $ua->request($request);
#    my @trackdbs;
    if (!$response->is_success) {
	my $str = "bad response when getting trackdbs (to delete them) for $study_id: ".$response->content."\t". $response->code;
	return (0,$str);
    }
    my $json_aref = decode_json($response->content);
    foreach my $trackdb (@{$json_aref->{trackdbs}}){
	my $uri = $trackdb->{uri};
	my ($success, $report) = del_trackdb($server, $user, $auth_token,$uri);
	return (0,$report) unless $success;
    }
    return 1;

}

sub del_trackdb {

    my ($server, $user, $auth_token,$uri) = @_;
    my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
    my $request = DELETE($uri);
    $request->headers->header(user       => $user);
    $request->headers->header(auth_token => $auth_token);
    my $response = $ua->request($request);
    if ($response->is_success) {
	return 1;
    } else {
	my $str = "Could not delete $uri: ".$response->content."\t".$response->code;
	return (0,$str);
    } 

}


sub register_track {
    

    my ($server, $user, $hub_url,$auth_token,$gca_hash) = @_;
    
    my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });

    my $request;
    if ($gca_hash) {
	$request = POST("$server/api/trackhub",
			'Content-type' => 'application/json',
			'Content'      => to_json({ url => $hub_url, assemblies => {%$gca_hash}  }));
    } else {
	$request = POST("$server/api/trackhub",
			'Content-type' => 'application/json',
			'Content'      => to_json({ url => $hub_url}));
    }
    $request->headers->header(user       => $user);
    $request->headers->header(auth_token => $auth_token);
    my $response = $ua->request($request);
    if ($response->is_success) {
	return 1;
    } else {
	my $str = "Couldn't register hub at $hub_url:".$response->content."\t".$response->code;
	return (0,$str);
    } 

}


sub registry_logout {

   my ($server, $user, $auth_token) = @_;
   my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });

   my $request = GET("$server/api/logout");
   $request->headers->header(user       => $user);
   $request->headers->header(auth_token => $auth_token);

   my $response = $ua->request($request);
   if ($response->is_success) {
       print "Logged out\n";
   } else {
       die sprintf "Unable to logout: %s [%d]", $response->content, $response->code;
   } 

}

1;
