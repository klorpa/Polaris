/obj/machinery/computer/robotics
	name = "robotics control console"
	desc = "Used to remotely lockdown or detonate linked cyborgs."
	icon_keyboard = "tech_key"
	icon_screen = "robot"
	light_color = "#a97faa"
	req_access = list(access_robotics)
	circuit = /obj/item/circuitboard/robotics

/obj/machinery/computer/robotics/attack_ai(var/mob/user as mob)
	ui_interact(user)

/obj/machinery/computer/robotics/attack_hand(var/mob/user as mob)
	ui_interact(user)

/obj/machinery/computer/robotics/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1)
	var/data[0]
	data["robots"] = get_cyborgs(user)
	data["is_ai"] = issilicon(user)


	ui = SSnanoui.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "robot_control.tmpl", "Robotic Control Console", 400, 500)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/obj/machinery/computer/robotics/Topic(href, href_list)
	if(..())
		return
	var/mob/user = usr
	if(!src.allowed(user))
		to_chat(user, "Access Denied")
		return

	// Locks or unlocks the cyborg
	if (href_list["lockdown"])
		var/mob/living/silicon/robot/target = get_cyborg_by_name(href_list["lockdown"])
		var/failmsg = ""
		if(!target || !istype(target))
			return

		if(isAI(user) && (target.connected_ai != user))
			to_chat(user, "Access Denied. This robot is not linked to you.")
			return

		if(isrobot(user))
			to_chat(user, "Access Denied.")
			return

		var/choice = input("Really [target.lockcharge ? "unlock" : "lockdown"] [target.name] ?") in list ("Yes", "No")
		if(choice != "Yes")
			return

		if(!target || !istype(target))
			return

		var/istraitor = target.mind.special_role
		if (istraitor)
			failmsg = "failed (target is traitor) "
			target.lockcharge = !target.lockcharge
			if (target.lockcharge)
				to_chat(target, "Someone tried to lock you down!")
			else
				to_chat(target, "Someone tried to lift your lockdown!")
		else if (target.emagged)
			failmsg = "failed (target is hacked) "
			target.lockcharge = !target.lockcharge
			if (target.lockcharge)
				to_chat(target, "Someone tried to lock you down!")
			else
				to_chat(target, "Someone tried to lift your lockdown!")
		else
			target.canmove = !target.canmove
			target.lockcharge = !target.canmove //when canmove is 1, lockcharge should be 0
			target.lockdown = !target.canmove
			if (target.lockcharge)
				to_chat(target, "You have been locked down!")
			else
				to_chat(target, "Your lockdown has been lifted!")
		message_admins("<span class='notice'>[key_name_admin(usr)] [failmsg][target.lockcharge ? "lockdown" : "release"] on [target.name]!</span>")
		log_game("[key_name(usr)] attempted to [target.lockcharge ? "lockdown" : "release"] [target.name] on the robotics console!")


	// Remotely hacks the cyborg. Only antag AIs can do this and only to linked cyborgs.
	else if (href_list["hack"])
		var/mob/living/silicon/robot/target = get_cyborg_by_name(href_list["hack"])
		if(!target || !istype(target))
			return

		// Antag synthetic checks
		if(!istype(user, /mob/living/silicon) || !(user.mind.special_role && user.mind.original == user))
			to_chat(user, "Access Denied")
			return

		if(target.emagged)
			to_chat(user, "Robot is already hacked.")
			return

		var/choice = input("Really hack [target.name]? This cannot be undone.") in list("Yes", "No")
		if(choice != "Yes")
			return

		if(!target || !istype(target))
			return

		message_admins("<span class='notice'>[key_name_admin(usr)] emagged [target.name] using the robotic console!</span>")
		log_game("[key_name(usr)] emagged [target.name] using robotic console!")
		target.emagged = 1
		to_chat(target, "<span class='notice'>Failsafe protocols overriden. New tools available.</span>")


// Proc: get_cyborgs()
// Parameters: 1 (operator - mob which is operating the console.)
// Description: Returns NanoUI-friendly list of accessible cyborgs.
/obj/machinery/computer/robotics/proc/get_cyborgs(var/mob/operator_mob)
	var/list/robots = list()

	for(var/mob/living/silicon/robot/R in mob_list)
		// Ignore drones
		if(istype(R, /mob/living/silicon/robot/drone))
			continue
		// Ignore antagonistic cyborgs
		if(R.scrambledcodes)
			continue

		var/list/robot = list()
		robot["name"] = R.name
		if(R.stat)
			robot["status"] = "Not Responding"
		else if (R.lockcharge)
			robot["status"] = "Lockdown"
		else
			robot["status"] = "Operational"

		if(R.cell)
			robot["cell"] = 1
			robot["cell_capacity"] = R.cell.maxcharge
			robot["cell_current"] = R.cell.charge
			robot["cell_percentage"] = round(R.cell.percent())
		else
			robot["cell"] = 0

		robot["module"] = R.module ? R.module.name : "None"
		robot["master_ai"] = R.connected_ai ? R.connected_ai.name : "None"
		robot["hackable"] = 0
		//Antag synths should be able to hack themselves and see their hacked status.
		if(operator_mob && isrobot(operator_mob) && (operator_mob.mind.special_role && operator_mob.mind.original == operator_mob) && (operator_mob == R))
			robot["hacked"] = R.emagged ? 1 : 0
			robot["hackable"] = R.emagged? 0 : 1
		// Antag AIs know whether linked cyborgs are hacked or not.
		if(operator_mob && isAI(operator_mob) && (R.connected_ai == operator_mob) && (operator_mob.mind.special_role && operator_mob.mind.original == operator_mob))
			robot["hacked"] = R.emagged ? 1 : 0
			robot["hackable"] = R.emagged? 0 : 1
		robots.Add(list(robot))
	return robots

// Proc: get_cyborg_by_name()
// Parameters: 1 (name - Cyborg we are trying to find)
// Description: Helper proc for finding cyborg by name
/obj/machinery/computer/robotics/proc/get_cyborg_by_name(var/name)
	if (!name)
		return
	for(var/mob/living/silicon/robot/R in mob_list)
		if(R.name == name)
			return R
