/**
* Name: Distributed_SHIBUYA
* Distributing Model of the Shibuya model
* Author: Lucas Grosjean
* Tags: HPC, Distribution Model, Shibuya, Load Balancing
*/

model DistributedSHIBUYA

import "Shibuya_Crossing_v12.gaml"  as continuous_move

global
{
	shape_file bounds <- shape_file("../includes/Shibuya.shp");
	geometry shape <- envelope(bounds);
	
	list<people> all_people_in_sub_model;
	
	int MPI_RANK;								// MPI RANK of the current  model instance
	int MPI_SIZE;								// number of MPI rank on the network
	int nb_people <- 100;						// number of people in the Shibuya Model
	int end_cycle <- 300;
	
	init
	{
		seed <- 50.0;
		
 		create Communication_Agent_MPI; 					// init of the communication agent
 		MPI_RANK <- Communication_Agent_MPI[0].MPI_RANK;	// get the MPI Rank of this instance
 		MPI_SIZE <- Communication_Agent_MPI[0].MPI_SIZE;	// get the size of the MPI Network
 		
		create continuous_move.main with:[seed::seed, nb_people::nb_people, end_cycle::end_cycle];
		ask(continuous_move.main[0])
		{
			all_people_in_sub_model <- list(people);
		}
		
		create centroid_agent number: MPI_SIZE
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
		
		ask centroid_agent
		{
			write("index centroid " + self.index);
			if(self.index != MPI_RANK) // kill agent from other centroids
			{
				ask self.my_points
				{
					scheduled <- false;
				}
			}
		}
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
 			write("DISTRIBUTION MODEL IS OVER FOR ISNTANCE " + MPI_RANK);
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
			write("Executing cycle " + cycle);
			do _step_;
			write("Cycle " + cycle + " Executed");
		}
	}
	
	reflex
	{
		write("DISTRIBUTION STEP--------------------- " + cycle);
		do _step_sub_model;
		write("post step");
		//if(cycle mod 2 = 0)
		//{	
			ask centroid_agent[MPI_RANK]
			{
				//write("myp_oints before main " + my_points);
				do update_centroid_location;
				do update_kmean;
				//write("my_points after main " + my_points);
			}
		//}
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
	
	list<unknown> get_attributes_from_people(people pe)
	{			
		list<list<unknown>> to_send <- list<list<unknown>>([pe.index, pe.location, [pe.last_state], pe.normal_speed, pe.dest, pe.final_dest, pe.wait_location]);
		write("to_send lenght 00 " + length(to_send));
		int index_current_waiting_area;
		if(pe.current_waiting_area != nil)
		{
			index_current_waiting_area <-  pe.current_waiting_area.index;
			write("index_current_waiting_area " + pe.current_waiting_area.index);
			to_send << list(index_current_waiting_area);
		}else
		{
			write("nto not " + index_current_waiting_area);
			to_send << list(nil);
		}
		
		int index_current_area;
		if(pe.current_area != nil)
		{
			index_current_area <-  pe.current_area.index;
			write("index_current_area " + pe.current_area.index);
			to_send << list(index_current_area);
		}else
		{
			write("nto not index_current_area " + index_current_waiting_area);
			to_send << list(nil);
		}
		
		int index_final_area;
		if(pe.final_area != nil)
		{
			index_final_area <-  pe.final_area.index;
			write("index_current_area " + pe.final_area.index);
			to_send << list(index_final_area);
		}else
		{
			write("nto not final_area " + index_final_area);
			to_send << list(nil);
		}
		
		write("to_send " + to_send);
		write("to_send lenght 00 " + length(to_send));
		
		
		return to_send;
	}
	action set_attributes_to_people(people pe, list<unknown> attributes)
	{			
		
		write("pe to change " + 			pe);
		write("pe attributes " + attributes);
		write("pe attributes lenght " + length	(attributes));
		write("pe index " + 			attributes[0][0]); 	// index
		write("pe location " + 		point(float(attributes[1][0]),float(attributes[1][1]))); 	// location
		write("pe last_state " + 		attributes[2][0]); 	// last_state
		write("pe normal_speed " + 	attributes[3][0]); 	// normal_speed
		write("pe dest " + 			point(float(attributes[4][0]),float(attributes[4][1]))); 	// dest
		write("pe final_dest " + 		point(float(attributes[5][0]),float(attributes[5][1]))); 	// final_dest
		write("pe wait_location " + 	attributes[6]); 	// wait_location
		write("pe current_waiting_area " + 	attributes[7]); 	// current_waiting_area
		write("pe current_area " + 	attributes[8]); 	// current_area
		write("pe cfinal_area " + 	attributes[9]); 	// current_area
		
		/*list<list<unknown>> to_send <- list<list<unknown>>(
		[	pe.index, 			//0
			pe.location, 		//1 
			[pe.last_state],	//2 
			pe.normal_speed, 	//3
			pe.dest, 			//4 
			pe.final_dest, 		//5 
			pe.wait_location	//6 
			pe.current_waiting_area // 7
			pe.current_waiting_area // 8
			
		]);*/
		
		
		pe.location <- point(float(attributes[1][0]),float(attributes[1][1]));
		pe.last_state <- attributes[2][0];
		pe.normal_speed <- float(attributes[3][0]);
		pe.dest <- point(float(attributes[4][0]),float(attributes[4][1]));
		pe.final_dest <- point(float(attributes[5][0]),float(attributes[5][1]));
		pe.wait_location <- attributes[6];
		//pe.current_waiting_area <- attributes[7];
		int index_wait_area;
		int index_current_area;
		int index_final_area;
		write("attributes[7] " + attributes[7]);
		if(attributes[7] != [])
		{
			write("attributes[7] != [] " + (attributes[7] != []));
			index_wait_area <- int(attributes[7]);
			pe.current_waiting_area <- waiting_area[index_wait_area];
			write("pe current_waiting_area withingh " + pe.current_waiting_area);
		}else
		{
			write("index_wait_area is null attributes[7] " + attributes[7]);
		}
		
		write("attributes[8] " + attributes[8]);
		if(attributes[8] != [])
		{
			write("attributes[8] != [] " + (attributes[8] != []));
			index_current_area <- int(attributes[8]);
			pe.current_area <- walking_area[index_current_area];
			write("pe waiting_area withingh " + pe.current_waiting_area);
		}else
		{
			write("index_current_area is null attributes[8] " + attributes[8]);
		}
		
		write("attributes[9] " + attributes[9]);
		if(attributes[9] != [])
		{
			write("attributes[9] != [] " + (attributes[9] != []));
			index_final_area <- int(attributes[9]);
			pe.final_area <- walking_area[index_final_area];
			write("pe waiting_area withingh " + pe.current_waiting_area);
		}else
		{
			write("final_area is null attributes[9] " + attributes[9]);
		}
		pe.scheduled <- true;
		
		write("pe last stte " + pe.last_state);
	}
	action update_centroid_location
	{
		map<int, list<list<unknown>>> receiving_centroids_location;
		map<int, list<list<unknown>>> sending_centroids_location;
		loop i from: 0 to: MPI_SIZE - 1
		{
			if(sending_centroids_location[i] = nil)
			{
				sending_centroids_location[i] <- list<list<unknown>>([]);
				sending_centroids_location[i] << list<list<unknown>>(list(self.index, self.location));
			}else
			{
				sending_centroids_location[i] << list<list<unknown>>(list(self.index, self.location));
			}
		}
		ask Communication_Agent_MPI
		{
			receiving_centroids_location <- MPI_ALLTOALL(sending_centroids_location);
			//write("receiving_centroids_location " + receiving_centroids_location);
		}
		
		loop centroids_location_list over: receiving_centroids_location
		{
			loop centroids_location over: list<list<unknown>>(centroids_location_list)
			{
				//write("centroids_location[0] " + int(centroids_location[0]));
				//write("centroids_location[1] " + point(centroids_location[1]));
				centroid_agent[int(centroids_location[0])].location <- point(centroids_location[1]);	
			}
		}
	}
	action update_kmean 
	{	
		map<int, list<list<unknown>>> migrating_agents;
		loop tmp over: my_points
		{
			centroid_agent closest <- centroid_agent closest_to tmp;
			if(closest != self)
			{
				//write("tmp leaving " + tmp);
				//add tmp to: self.mypoints;
				if(migrating_agents[closest.index] = nil)
				{
					migrating_agents[closest.index] <- list<list<unknown>>([]);
					//migrating_agents[closest.index] << list<list<unknown>>(list(tmp.index, tmp.location, [tmp.last_state]));
					migrating_agents[closest.index] << get_attributes_from_people(tmp);
				}else
				{
					migrating_agents[closest.index] << get_attributes_from_people(tmp);
				}
			}
		}
		
		write("migrating_agents " + migrating_agents);
		
		map<int, list<list<unknown>>> data_recv;
		ask Communication_Agent_MPI
		{
			data_recv <- MPI_ALLTOALL(migrating_agents);
			write("data_recv " + data_recv);
		}
		
		loop migrating_agent_list over: migrating_agents
		{
			//write("migrating_agent_list " + migrating_agent_list);
			loop migrating_agent over: list<list<unknown>>(migrating_agent_list)
			{
				//write("migrating_agent " + migrating_agent);
				//write("migrating_agent lenght " + length(migrating_agent));
				
				//write("migrating_agent 0 " + migrating_agent[0]);
				//write("migrating_agent 1 " + migrating_agent[1]);
				
				int agent_index <- int(migrating_agent[0][0]);
				//write("agent_index to remove " + agent_index);
				//write("my_points " + my_points);
				all_people_in_sub_model[agent_index].scheduled <- false;
				remove all_people_in_sub_model[agent_index] from: my_points;
				//write("my_points after" + my_points);
			}
		}
		
		write("data_recv" + data_recv);
		loop received_agent_list over: data_recv
		{
			//write("received_agent_list " + received_agent_list);
			loop received_agent over: list<list<unknown>>(received_agent_list)
			{
				//write("received_agent " + received_agent);
				//write("received_agent 0 " + received_agent[0]);
				//write("received_agent 1 " + received_agent[1]);
				//write("received_agent int " + int(received_agent[0][0]));
				//write("received_agent point " + point(received_agent[1]));
				
				//write("received_agent[2][0] " + received_agent[2][0]);
				//write("received_agent[2] " + received_agent[2]);
				//write("received_agent[2][0]  cast " + string(received_agent[2][0]));
				
				int agent_index <- int(received_agent[0][0]);
				//write("agent_index " + int(received_agent[0]));
				//write("agent_index " + agent_index);
				/*write("???");
				write("received_agent[2] lenght " + string(received_agent[2][0]));
				string last_state <- string(received_agent[2][0]);
				string last_state2 <- received_agent[2][0];
				
				write("last_state " + last_state);
				write("last_state2 " + last_state2);
				
				all_people_in_sub_model[agent_index].scheduled <- true;
				all_people_in_sub_model[agent_index].location <- point(received_agent[1]);
				all_people_in_sub_model[agent_index].last_state <- last_state;
				
				write("all_people_in_sub_model[agent_index].last_state " + all_people_in_sub_model[agent_index].last_state);
				add all_people_in_sub_model[agent_index] to: my_points;*/
				
				do set_attributes_to_people(all_people_in_sub_model[agent_index], received_agent);
				add all_people_in_sub_model[agent_index] to: my_points;
			}
		}
		
		my_points <- my_points where !dead(each);
		location <- mean(my_points collect each.location); // move centroid in the middle of the convex
	}
	
	aspect default
	{
		if(index = MPI_RANK)
		{
			draw cross(2, 0.5) color: color_kmean;
			draw "" + length(my_points) + " peoples " font: font('Default', 15, #bold) color: #black;
			convex <- convex_hull(polygon(my_points));
			draw convex color: rgb(color_kmean,0.2) border: #black;
		}
	}
}

species Communication_Agent_MPI skills:[MPI_SKILL]{} // communication agent with MPI Librairy

experiment distributed type: MPI_EXP
{
	reflex snapshot // take a snapshot of the current distribution model instance
	{
		write("SNAPPING___________________________________ " + cycle);
		int mpi_id <- MPI_RANK;
		ask simulation
		{	
			save (snapshot("shibuya")) to: "../output.log/snapshot/" + mpi_id + "/shibuya_" + cycle + ".png" rewrite: true;		
			save (snapshot("centroid")) to: "../output.log/snapshot/" + mpi_id + "/centroid_" + cycle + ".png" rewrite: true;		
			
		}
	}
	output 
	{
		display shibuya
		{
			graphics "exit" {
				ask continuous_move.main[0].simulation
				{
					loop tmp over: people
					{			
						if(tmp.scheduled)
						{					
							draw circle(0.5) at: tmp.location color: #blue;	
							draw "" + tmp.index at: tmp.location font: font('Default', 8) color: #black;
						}else
						{
							draw circle(0.5) at: tmp.location color: #red;	
						}	
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
		
	}
}
