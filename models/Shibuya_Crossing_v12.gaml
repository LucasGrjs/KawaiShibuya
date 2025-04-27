 /**
* Name: KawaiShibuyaCrossing
* 
* Author: Tri Nguyen-Huu, Patrick Taillandier
* 
* This is a simulation of Shibuya Crossing (Tokyo, Japan).
*
*
* Tags: pedestrian skill, driving skill, SFM, Shibuya, Tokyo, Kawai
*/

model KawaiShibuyaCrossing

import "EyeCandies/trains.gaml"
import "EyeCandies/props.gaml"
import "EyeCandies/cars.gaml"

global {

	bool simulationOver <- false;
	int end_cycle <- 1000;
	
	int nb_people <- 2000;
	float step <- 0.25#s;
	
	float precision <- 0.2;
	float factor <- 1.0;
	float mesh_size <- 2.0;
	
	bool show_fps <- true;
	float mtime <- machine_time;
	
	shape_file bounds <- shape_file("../includes/Shibuya.shp");
	image_file photo <- (image_file(("../includes/Shibuya.png")));

	shape_file crosswalk_shape_file <- shape_file("../includes/crosswalk.shp");
	shape_file walking_area_shape_file <- shape_file("../includes/walking area.shp");
	shape_file traffic_signals_shape_file <- shape_file("../includes/traffic_signals.shp");

	
	geometry shape <- envelope(bounds);
	
	
	float P_shoulder_length <- 1.0 parameter: true category: "Pedestrian simulation";
	float P_proba_detour <- 0.5 parameter: true category: "Pedestrian simulation";
	bool P_avoid_other <- true parameter: true category: "Pedestrian simulation";
	float P_obstacle_consideration_distance <- 3.0 parameter: true category: "Pedestrian simulation";
	float P_pedestrian_consideration_distance <- 3.0 parameter: true category: "Pedestrian simulation";
	float P_tolerance_target <- 0.1 parameter: true category: "Pedestrian simulation";
	bool P_use_geometry_target <- true parameter: true category: "Pedestrian simulation";
	
	
	string P_model_type <- "simple" among: ["simple", "advanced"] parameter: true category: "Pedestrian simulation"; 
	string pedestrian_path_init <- "grid" among: ["voronoi", "grid"] parameter: true category: "Pedestrian simulation"; 
	
	float P_A_pedestrian_SFM_advanced parameter: true <- 0.0001 category: "SFM advanced" ;
	float P_A_obstacles_SFM_advanced parameter: true <- 1.9 category: "SFM advanced" ;
	float P_B_pedestrian_SFM_advanced parameter: true <- 0.1 category: "SFM advanced" ;
	float P_B_obstacles_SFM_advanced parameter: true <- 1.0 category: "SFM advanced" ;
	float P_relaxion_SFM_advanced  parameter: true <- 0.5 category: "SFM advanced" ;
	float P_gama_SFM_advanced parameter: true <- 0.35 category: "SFM advanced" ;
	float P_lambda_SFM_advanced <- 0.1 parameter: true category: "SFM advanced" ;
	float P_minimal_distance_advanced <- 0.25 parameter: true category: "SFM advanced" ;
	
	float P_n_prime_SFM_simple parameter: true <- 3.0 category: "SFM simple" ;
	float P_n_SFM_simple parameter: true <- 2.0 category: "SFM simple" ;
	float P_lambda_SFM_simple <- 2.0 parameter: true category: "SFM simple" ;
	float P_gama_SFM_simple parameter: true <- 0.35 category: "SFM simple" ;
	float P_relaxion_SFM_simple parameter: true <- 0.54 category: "SFM simple" ;
	float P_A_pedestrian_SFM_simple parameter: true <-4.5category: "SFM simple" ;
	graph network;
	

	bool can_cross <- false;
//	float time_since_last_spawn <- 0.0;
	
	people the_people;
	//point endpoint;
//	int schedule_step <- 0;
//	float schedule_time <- 0.0;
//	float time_to_clear_crossing <- 0.0;
//	float percent_time_remaining <- (schedule_times[0] )/(schedule_times[5] + schedule_times[0] - schedule_times[1]);
//
//		list<float> schedule_times <- [ 15#s, // pedestrian light to green
//									60#s, // pedestrian light to red
//									85#s, // car group 1 to green
//									100#s,// car group 1 to red
//									105#s,// car group 2 to green
//									120#s // car group 2 to red
//								  ];	
	
	geometry open_area;


	list<geometry> walking_area_divided;
	list<point> nodes;
	list<geometry> nodes_inside;
	list<geometry> voronoi_diagram;
	geometry bounds_shape;
	int target_pop <- nb_people;
	
	init {
		gama.pref_opengl_z_factor <- 0.0;
		

		
		create crosswalk from:crosswalk_shape_file with:[id::int(get("id"))];
		create walking_area from:walking_area_shape_file;
		
		ask crosswalk{
			ends <- walking_area overlapping self;
		}
		
		loop w over:  walking_area{
			loop c over: (crosswalk overlapping w){
				create waiting_area{
					shape <- intersection(w.shape,c.shape);
					my_crosswalk <- c;
					my_walking_area <- w;
					w.waiting_areas <+ self;
					c.waiting_areas <+ self;
				}
			}
		}
		
		loop c over: crosswalk{
			loop w over: c.waiting_areas{
				w.opposite <- first(c.waiting_areas - w);
			}
		}
		
		
		open_area <- union(walking_area collect each.shape);
		bounds_shape <- open_area - union(building collect each.shape);	

		if pedestrian_path_init = "voronoi"{
			list<geometry> lg;
			loop w over: walking_area{	
				walking_area_divided <- walking_area_divided + split_geometry(w - union(building collect (each.shape)),mesh_size);
			}
			
			voronoi_diagram <- voronoi(walking_area_divided accumulate(each.points));
			voronoi_diagram <- voronoi_diagram collect((each inter (open_area - 0.5)) - (union(building collect (each.shape))+0.5));
			lg <- voronoi_diagram accumulate (to_segments(each));
			create pedestrian_path from: lg;
		}else{
			float minx <- min(envelope(open_area).points accumulate each.x);
			float maxx <- max(envelope(open_area).points accumulate each.x);
			float miny <- min(envelope(open_area).points accumulate each.y);
			float maxy <- max(envelope(open_area).points accumulate each.y);
	
			float area_width <- maxx-minx;
			float area_height <- maxx-minx;
					
			list<geometry> lines;
			int num <- int(area_width/mesh_size);
			loop k from: 0 to: num {
				lines << line([{k * area_width/num, 0}, {k * area_width/num, area_height}]);
			}
			num <- int(area_height/mesh_size);
			loop k from: 0 to: num {
				lines << line([{0, k * area_height/num, 0}, {area_width, k * area_height/num}]);	
			}
				
			list<geometry> clean_lines <- [];
			loop w over: walking_area{
				list<geometry> tmp <- lines collect(inter(each,w));
				tmp <- clean_network(union(tmp).geometries, 0.001, true, true);
				list<point> pl <- remove_duplicates(tmp accumulate(each.points));
				loop p over: pl{
					list<point> np <- (pl where ((each distance_to p) < mesh_size*sqrt(2)*1.01))
						-(pl where ((each distance_to p) < mesh_size*1.01)); 
					tmp <- tmp + (np collect(polyline([p,each])));
				}
				clean_lines <- clean_lines + remove_duplicates(tmp);
			}
			clean_lines <- clean_lines where (bounds_shape covers each);		
			create pedestrian_path from: clean_lines{
				free_space <- shape + (mesh_size*0.6);
			}
		}
		
		nodes <-remove_duplicates(pedestrian_path accumulate ([first(each.shape.points),last(each.shape.points)]));		
		nodes_inside <- (nodes collect geometry(each)) inside open_area;
		
		ask waiting_area{
			do compute_direction;
		}
		
		network <- as_edge_graph(pedestrian_path);
		
//		ask pedestrian_path {
//			do build_intersection_areas pedestrian_graph: network;
//		}
		

		create people number:nb_people{
		//	do add_people;
		}	
	
	//	create debug;


		create traffic_signal from: traffic_signals_shape_file with:[group::int(get("group")),crosswalk_left::int(get("cw_l")),
				crosswalk_right::int(get("cw_r")),car_light::string(get("car_light")),direction_crosswalk::int(get("dir_crossw"))]{
			point dir <- (first(crosswalk where (each.id=direction_crosswalk)).waiting_areas closest_to self).direction;
			heading <- towards({0,0},dir);
			if crosswalk_left >0{
				point dir_l <- (first(crosswalk where (each.id=crosswalk_left)).waiting_areas closest_to self).direction;
				heading_l <- towards({0,0},dir_l);	
			}
			if crosswalk_right >0{
				point dir_r <- (first(crosswalk where (each.id=crosswalk_right)).waiting_areas closest_to self).direction;
				heading_r <- towards({0,0},dir_r);	
			}	
		}
	}

	action switch_pedestrian_lights{
		can_cross <- !can_cross;
		if can_cross {
			ask people{
				waiting <- false;
			}
		}else{
			loop w over: waiting_area{
				ask people inside w{
					waiting <- true;
				}
			}
		}
	}
	
	reflex change_people_number{
		write("change_people_number ");
		int variation <- nb_people - (people count(each.fade_status != "fade_away"));
		write("post variation change_people_number " + variation);
		if variation < 0{
			write("if  ?");
			ask (-variation among people where (each.fade_status != "fade_away")){
				fade_status <- "fade_away";
			}
		}
		if variation > 0{
			/*create people number: variation{
				fade_status <- "fade_in";
				fading <- 0.0;
			}*/
		}
	}
	
	reflex compute_fps when: show_fps and mod(cycle,100)=0 and cycle > 100{
		float newmtime <- machine_time;
		if cycle > 0{
			write ""+round(100000/(newmtime-mtime)*10)/10+" fps.";
		}
		mtime <- newmtime;
	}
	
	reflex main_scheduler{
		// change traffic lights
		if schedule_step = 1{
			percent_time_remaining <- (schedule_times[1] - schedule_time)/(schedule_times[1] - schedule_times[0]);
		}else if schedule_step = 0{
			percent_time_remaining <- (schedule_times[0] - schedule_time)/(schedule_times[5] + schedule_times[0] - schedule_times[1]);
		}else{
			percent_time_remaining <- (schedule_times[0]+schedule_times[5] - schedule_time)/(schedule_times[5] + schedule_times[0] - schedule_times[1]);			
		}
				
		switch schedule_step{		
			match 0{
				if  schedule_time > schedule_times[0]{
					do switch_pedestrian_lights;
					schedule_step <- schedule_step + 1;
					percent_time_remaining <- 1.0;
				}
			}
			match 1{
				if schedule_time > schedule_times[1]{
					do switch_pedestrian_lights;
					schedule_step <- schedule_step + 1;
					time_to_clear_crossing <- schedule_times[2]-schedule_times[1];
					percent_time_remaining <- 1.0;
				}
			}
			match 2{
				time_to_clear_crossing <- time_to_clear_crossing - step;
				if schedule_time > schedule_times[2]{
					ask intersection where (each.group = 1){
						do to_green;
					}
					schedule_step <- schedule_step + 1;
				}
			}
			match 3 {
				if schedule_time > schedule_times[3]-3#s{
					ask intersection where (each.group = 1){
						do to_orange;
					}
				}
				if schedule_time > schedule_times[3]{
					ask intersection where (each.group = 1){
						do to_red;
					}
					schedule_step <- schedule_step + 1;
				}
			}
			match 4 {
				if schedule_time > schedule_times[4]{
					ask intersection where (each.group = 2){
						do to_green;
					}
					schedule_step <- schedule_step + 1;
				}
			}
			match 5{
					if schedule_time > schedule_times[5]-3#s{
					ask intersection where (each.group = 2){
						do to_orange;
					}
				}
				if schedule_time > schedule_times[5]{
					ask intersection where (each.group = 2){
						do to_red;
					}
					schedule_step <- 0;
					schedule_time <- - step;
				}
			}
		}
		schedule_time <- schedule_time + step;
	}
	
	reflex stop_simulation when: cycle = end_cycle
	{
		simulationOver <- true;
		write("total_duration " + float(total_duration)/1000 + "s");
		do pause;
	}
}

/*******************************************
 * 
 * 
 *     species definition
 * 
 * 
 * ***************************************** */

species pedestrian_path skills: [pedestrian_road]{
	rgb color <- #gray;
	walking_area my_area;
	
	aspect default { 
		draw shape  color: color;
	}
	aspect free_area_aspect {
		draw shape  color: color;
		draw free_space color: rgb(color,20) border: #black;
	}
}



species walking_area {
	list<waiting_area> waiting_areas;
	aspect default {
		switch int(self){
			match 0 {
				draw shape color: #green border: #black;
			}
			match 1 {
				draw shape color: #blue border: #black;
			}
			match 2 {
				draw shape color: #orange border: #black;
			}
			match 3 {
				draw shape color: #red border: #black;
			}
		}
	}
}

species crosswalk {
	int id;
	list<walking_area> ends;
	list<waiting_area> waiting_areas;
	
	aspect default {
		draw shape color: #gray border: #black;
	}
}

species waiting_area{
	crosswalk my_crosswalk;
	walking_area my_walking_area;
	waiting_area opposite;
	point direction;
	geometry waiting_front;
	
	action compute_direction{
		float norm <- 0.0;
		direction <- {0,0};
		loop i from: 0 to: length(my_crosswalk.shape.points)-2{
			if norm(my_crosswalk.shape.points[i+1]-my_crosswalk.shape.points[i]) > norm{
				direction <- my_crosswalk.shape.points[i+1]-my_crosswalk.shape.points[i];
				norm <- norm(direction);
			}	
		}
		if direction.x * (opposite.location.x - self.location.x) + direction.y * (opposite.location.y - self.location.y) < 0{
			direction <- -direction;
		}
		waiting_front <- polyline((shape.points where (direction.x*(each.x -location.x)+direction.y*(each.y -location.y)>0)) collect each);
		
	}
	
	aspect default {
		draw shape color: #yellow border: #black;
		draw waiting_front width: 5 color: #red;
	}
}




species people skills: [pedestrian] control: fsm parallel: false{
	rgb color <- rnd_color(255);
	float normal_speed <- gauss(5.2,1.5) #km/#h min: 2.5 #km/#h;
	float scale <- rnd(0.9,1.1);
	point dest;
	point final_dest;
	walking_area final_area;
	walking_area current_area;
	waiting_area current_waiting_area;
	bool going_to_cross <- false;
	bool waiting <- false;
	point wait_location;
	list<point> tracking;
	string last_state;
	bool for_debug <- false;
	string fade_status <- "none";
	float fading <- 1.0;
	bool scheduled <- true;

	reflex fade_away when: fade_status="fade_away"{
		write("fade_away " + self);
		fading <- fading - 0.01;
		if fading < 0 {
			do die;
		}
	}
	
	reflex fade_in when: fade_status="fade_in"{
		write("fade_in " + self);
		fading <- fading + 0.01;
		if fading >= 1 {
			fade_status <- "none";
		}
	}
	
	init{
		obstacle_species<-[building];
		location <- any_location_in(world.bounds_shape);
		dest <- location;
		final_dest <- location;
		current_waiting_area <- nil;

		obstacle_consideration_distance <-P_obstacle_consideration_distance;
		pedestrian_consideration_distance <-P_pedestrian_consideration_distance;
		shoulder_length <- P_shoulder_length;
		avoid_other <- P_avoid_other;
		proba_detour <- P_proba_detour;
		
		use_geometry_waypoint <- P_use_geometry_target;
		tolerance_waypoint<- P_tolerance_target;
		pedestrian_species <- [people];
		
		pedestrian_model <- P_model_type;
		
	
		if (pedestrian_model = "simple") {
			A_pedestrians_SFM <- P_A_pedestrian_SFM_simple;
			relaxion_SFM <- P_relaxion_SFM_simple;
			gama_SFM <- P_gama_SFM_simple;
			lambda_SFM <- P_lambda_SFM_simple;
			n_prime_SFM <- P_n_prime_SFM_simple;
			n_SFM <- P_n_SFM_simple;
		} else {
			A_pedestrians_SFM <- P_A_pedestrian_SFM_advanced;
			A_obstacles_SFM <- P_A_obstacles_SFM_advanced;
			B_pedestrians_SFM <- P_B_pedestrian_SFM_advanced;
			B_obstacles_SFM <- P_B_obstacles_SFM_advanced;
			relaxion_SFM <- P_relaxion_SFM_advanced;
			gama_SFM <- P_gama_SFM_advanced;
			lambda_SFM <- P_lambda_SFM_advanced;
			minimal_distance <- P_minimal_distance_advanced;
		
		}
	}
	
	state unscheduled
	{
		//write("I'm " + self + " and " + scheduled + " from " + last_state);
		transition to:find_new_destination when: scheduled and last_state = "find_new_destination";	
		transition to:go_to_grid_before_final_destination when: scheduled and last_state = "go_to_grid_before_final_destination";	
		transition to:go_to_final_destination when: scheduled and last_state = "go_to_final_destination";	
		transition to:go_to_grid_before_crosswalk when: scheduled and last_state = "go_to_grid_before_crosswalk";	
		transition to:go_to_crosswalk when: scheduled and last_state = "go_to_crosswalk";	
		transition to:waiting_to_cross when: scheduled and last_state = "waiting_to_cross";	
		transition to:crossing when: scheduled and last_state = "crossing";	
	}
	
	state find_new_destination initial: true{
		enter
		{ 
			write("enter self " + self + " " + scheduled + " last " + last_state);
		}
		write("???");
		write("find_new_destination " + self + " scheduled " + scheduled);
		speed <- normal_speed;
		write("1f");
		final_dest <- one_of(nodes_inside).location;
		write("2f ");
		final_area <- walking_area closest_to final_dest;
		write("3f");
		current_waiting_area <- nil;
		write("4f");
		current_area <- walking_area closest_to self.location;	
		write("5f");
		tracking <- [location];
		write("6f");
			
		write("current_area = final_area " + (current_area = final_area));
		write("current_area = final_area " + current_area != final_area);
		
		transition to: unscheduled when: !scheduled;
		transition to: go_to_grid_before_final_destination when: current_area = final_area;
		transition to: go_to_grid_before_crosswalk when: current_area != final_area;
		last_state <- "find_new_destination";
	}
	
	state go_to_grid_before_final_destination{
		write("go_to_grid_before_final_destination " + self + " scheduled " + scheduled);
		enter{
			write("enter go_to_grid_before_final_destination + " + self);
			speed <- normal_speed;		
			write("1s");
			dest <- nodes closest_to self;
			write("2s");
		}
			write("3s");
		do walk_to target: dest;
			write("4s");
		if  norm(location - dest) < precision{
			write("5s");
			location <- dest;
		}
			write("6s");
		transition to: unscheduled when: !scheduled;
		transition to: go_to_final_destination when: norm(location - dest) < precision;
		last_state <- "go_to_grid_before_final_destination";
	}
	
	state go_to_final_destination{
		write("go_to_final_destination " + self + " scheduled " + scheduled);
		enter{
			write("1a");
			dest <- final_dest;
			write("2a");
			dest <- nodes closest_to dest;
			write("3a");
			tracking <+ location;
			write("4a");
			if norm(location - dest)>= precision{	
				write("5a " + dest);
				//write("5ab " + network);
				do compute_virtual_path pedestrian_graph:network target: dest;
				write("5.5a");
			}
		}
		write("before ifa " + dest);
		write("before ifa " + location);
		if norm(location - dest)>= precision{	
			write("6a " + norm(location - dest));
			do walk;
			write("6.5a " + norm(location - dest));
			write("after iwalkfa " + location);
		}
		write("after ifa " + (norm(location - dest) < precision));
		transition to: unscheduled when: !scheduled;
		transition to: find_new_destination when: norm(location - dest) < precision;
		last_state <- "go_to_final_destination";
	}
	
	state go_to_grid_before_crosswalk{
		write("go_to_grid_before_crosswalk " + self + " scheduled " + scheduled);
		enter{
			speed <- normal_speed;
			dest <- nodes closest_to self;
			tracking <+ location;
		}
		do walk_to target: dest;
		last_state <- "go_to_final_destination";
		if  norm(location - dest) < precision{
			location <- dest;
		}
		transition to: unscheduled when: !scheduled;
		transition to: go_to_crosswalk when: norm(location - dest) < precision ;
		last_state <- "go_to_grid_before_crosswalk";
	}
	
	state go_to_crosswalk{
		write("go_to_crosswalk " + self + " scheduled " + scheduled);
		enter{
			write("enter go_to_crosswalk " + self);
			current_waiting_area <- 
				first(current_area.waiting_areas where (each.opposite.my_walking_area = final_area));
			write("current_waiting_area  " + current_waiting_area);
			if current_waiting_area = nil{
				current_waiting_area <- one_of(current_area.waiting_areas);
				write("current_waiting_area nil  " + current_waiting_area);
			}				
			dest <- any_location_in(current_waiting_area);
			write("dest1  " + dest);
			dest <- nodes closest_to dest;
			write("dest2  " + dest);
			tracking <+ location;
			if norm(location - dest)>= precision{	
				write("norm  " + norm(location - dest));
				do compute_virtual_path pedestrian_graph:network target: dest;
			}			
		}
		write("location " + location);
		write("dest " + dest);
		if norm(location - dest)>= precision{	
			write("walk 1 " + norm(location - dest));
			do walk;
			write("walk 2 " + norm(location - dest));
			write("location " + location);
		}
		last_state <- "go_to_crosswalk";
		transition to: unscheduled when: !scheduled;
		transition to: waiting_to_cross when: (norm(location - dest) < precision+2*shoulder_length);
	}
	
	state waiting_to_cross{
		write("waiting_to_cross " + self + " scheduled " + scheduled);
		enter{
			dest <- first(point(intersection(polyline(current_area.shape.points),polyline([location, location+current_waiting_area.direction]))));
			if dest = nil{
				dest <- any_location_in(current_waiting_area);
			}
			tracking <+ location;
		}	
		do walk_to target: dest;
		last_state <- "waiting_to_cross";
		transition to: unscheduled when: !scheduled;
		transition to: crossing when: can_cross and (norm(location - dest) < 2);
	}
	
	state crossing{
		write("crossing " + self + " scheduled " + scheduled);
		enter{
			write("enter crossing " + self);
			write("crossing current_waiting_area " + current_waiting_area);
			write("crossing current_waiting_area opposite " + current_waiting_area.opposite);
			write("crossing wait_location " + wait_location);
			geometry crossing_target <- intersection(current_waiting_area.opposite.shape,polyline([wait_location-current_waiting_area.direction,wait_location+current_waiting_area.direction]));
			
			write("enter crossing_target " + crossing_target);
			if crossing_target != nil{
				dest <- any_location_in(crossing_target);
			}else{
				dest <- any_location_in(current_waiting_area.opposite);
			}
			write("enter dest " + dest);
			tracking <+ location;
			write("enter walking_area " + walking_area);
			write("enter walking_area opposite " + current_waiting_area.opposite);
			current_area <- walking_area closest_to current_waiting_area.opposite;
			write("enter current_area " + current_area);
		}
		if !can_cross{// boost to finish crossing before green light
			write("can_crosscan_crosscan_cross ");
			speed <- max(1,norm(dest-location)/(1#s+time_to_clear_crossing)) * normal_speed;
			write("crossing speed " + speed);
		}
		write("walking cross speed " + speed);
		do walk_to target: dest;
		write("dest " + dest);
		write("self.location distance_to current_area " + self.location distance_to current_area);
		bool other_side_reached <- self.location distance_to current_area < 1#m;
		write("other_side_reached " + other_side_reached);
		
		transition to: unscheduled when: !scheduled;
		//transition to: go_to_crosswalk when: other_side_reached and (current_area != final_area);
		last_state <- "crossing";
		transition to: go_to_grid_before_crosswalk when: other_side_reached and (current_area != final_area);
		transition to: go_to_grid_before_final_destination when: other_side_reached and (current_area = final_area);
	}

	aspect default {
		//draw square(shoulder_length/2 ) at: location+{shoulder_length/5, shoulder_length/5}color: #black;
		draw square(shoulder_length/2 ) at: location+{0,0,0.1} color: color;
	}
}



experiment main type: gui parent: "Parameter panel" {
	output {
		/*display map type: 3d axes: false background: #darkgray{
			camera 'default' location: {98.4788,143.3489,64.7132} target: {98.6933,81.909,0.0};
			image photo refresh: false transparency: 0 ;	

			//species train;// transparency: 0.03;
			//species carriage;// transparency: 0.3;
			species fake_building transparency: 0.9;			
			species people; //aspect: 2d;
			//species car aspect: kawai;// transparency: 0.3;
			//species traffic_signal;
			//species building transparency: 0.3;
			//species tree transparency: 0.3;

		}*/
		
		/*display 2d
		{		
			species people; 
		}*/
	}
}

