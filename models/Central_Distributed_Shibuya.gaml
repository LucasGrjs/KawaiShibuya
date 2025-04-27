/**
* Name: Central_Distributed_SHIBUYA
* Centralized test for distributing the Shibuya model
* Author: Lucas Grosjean
* Tags: HPC, Distribution Model, Shibuya, Load Balancing
*/

model DistributedSHIBUYA

import "Shibuya_Crossing_v12.gaml"  as continuous_move

global
{
	shape_file bounds <- shape_file("../includes/Shibuya.shp");
	geometry shape <- envelope(bounds);
	
	int number_of_centroids <- 16;
	list<point> centroids_position;
	list<people> all_people_in_sub_model;
	field instant_heatmap <- field(200,200);
	
	init
	{
		create continuous_move.main;
		ask(continuous_move.main[0])
		{
			all_people_in_sub_model <- list(people);
		}
		
		create centroid_agent number: number_of_centroids
		{
			location <- one_of(all_people_in_sub_model).location;
		}
		
		loop agt over: all_people_in_sub_model
		{
			centroid_agent one_centroids <- centroid_agent closest_to agt;
			ask one_centroids
			{
				add agt to: my_points;
			}
		}
		
		do test;
	}
	
	bool check_end_simulation
 	{
 		bool end_simu <- false;
 		ask continuous_move.main[0].simulation
 		{
	 		if(simulationOver) // check if sub model is done simulating
	 		{	
	 			end_simu <- true;
	 			write(" ");
	 			write("SIMULATION IS OVER");
	 		}	
 		}
 		return end_simu;
 	}
 	
 	action end_simulations
	{
 		if(check_end_simulation())
 		{	
 			write("DISTRIBUTION MODEL IS OVER");
 			write("total_duration " + float(total_duration)/1000 + "s");
 			
 			ask continuous_move.main[0].simulation
 			{
 				do die;
 			}
	 		do die;
	 		
 		}
	}
 	
	action _step_sub_model
	{	
 		do end_simulations();			// check end of the model
		ask continuous_move.main[0].simulation
		{
			//write("stepping");
			do _step_;
			
			all_people_in_sub_model <- list(people);
			
			instant_heatmap[] <- 0 ;
			ask all_people_in_sub_model {
				instant_heatmap[location] <- instant_heatmap[location] + 1;
			}
		}
	}
	
	reflex
	{
		do _step_sub_model;
	}
	
	action test
	{
		ask centroid_agent
		{
			write("index centroid " + self.index);
			centroids_position << self.location;
		}
	}
}

species centroid_agent
{
	rgb color_kmean;
	list<people> my_points;
	list<people> tmp_my_points;
	geometry convex;
	
	init
	{
		color_kmean <- rgb(rnd(255),rnd(255),rnd(255));
	}
	reflex
	{	
		map<int, list<people>> migrating_agents;
		loop tmp over: my_points
		{
			centroid_agent closest <- centroid_agent closest_to tmp;
			if(closest = nil)
			{
				ask simulation
				{
					do pause;
				}
			}
			if(closest != self)
			{
				//write("tmp leaving " + tmp);
				//add tmp to: self.mypoints;
				if(migrating_agents[closest.index] = nil)
				{
					migrating_agents[closest.index] <- list<people>(tmp);
				}else
				{
					migrating_agents[closest.index] << tmp;
				}
			}
		}
		
		loop migrating_agent over: migrating_agents.pairs
		{
			//write("migrating_agent " + migrating_agent);
			//write("migrating_agent.keyu " + migrating_agent.key);
			//write("migrating_agent.value " + migrating_agent.value);
			
			centroid_agent migrate_to <- centroid_agent[migrating_agent.key];
			ask migrate_to
			{
				tmp_my_points <- tmp_my_points + list<people>(migrating_agent.value);
				//write("hello " + self);
				//write("hello " + self.tmp_my_points);
			}
			
			//write("my_points before " + my_points);
			loop migrating_agent_to_remove over: migrating_agent.value
			{
				remove migrating_agent_to_remove from: my_points;
			}
			//write("my_points afetr " + my_points);
		}
		
		//write("tmp_my_points " + tmp_my_points);
		my_points <- my_points + tmp_my_points;
		tmp_my_points <- [];
		
		//write("migrating_agent " + migrating_agents);
		//write("lenght["+self+"] : " + length(mypoints));
		my_points <- my_points where !dead(each);
		location <- mean(my_points collect each.location); // move centroid in the middle of the convex
	}
	
	aspect default
	{
		draw cross(2, 0.5) color: color_kmean;
		draw "" + length(my_points) + " peoples " font: font('Default', 15, #bold) color: #black;
		convex <- convex_hull(polygon(my_points));
		draw convex color: rgb(color_kmean,0.2) border: #black;
	}
}

experiment distributed type:gui
{
	output 
	{
		display shibuya
		{
			graphics "exit" {
				ask continuous_move.main[0].simulation
				{
					loop tmp over: people
					{				
						draw circle(0.5) at: tmp.location color: tmp.color;	
					}
					loop tmp over: building
					{
						draw tmp color: #gray depth: tmp.height border: #black;
					}
				}
			}
		}
		display centroid
		{
			species centroid_agent;
		}
		display heatmap type: 2d axes: false
		{
			mesh instant_heatmap scale: 1 color: palette([ #black, #coral, #orange, #darkgoldenrod, #firebrick, #red, #darkred, #red, #red]);
		}
		
	}
}
