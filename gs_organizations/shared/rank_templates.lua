---------------------------------------------------------------------
-- GS Organizations
--
-- File: rank_templates.lua
-- Purpose:
--     Organization rank seed templates
---------------------------------------------------------------------

GS = GS or {}
GS.OrganizationRankTemplates = GS.OrganizationRankTemplates or {}

local Permissions = GS.OrganizationPermissions

local function AllPermissions()
    local permissions = {}

    for _, permission in pairs(Permissions) do
        permissions[permission] = true
    end

    return permissions
end

local function PermissionSet(values)
    local permissions = {}

    for _, permission in ipairs(values) do
        permissions[permission] = true
    end

    return permissions
end

local owner = AllPermissions()

local manager = PermissionSet({
    Permissions.INVITE_MEMBER,
    Permissions.REMOVE_MEMBER,
    Permissions.KICK_MEMBER,
    Permissions.PROMOTE_MEMBER,
    Permissions.DEMOTE_MEMBER,
    Permissions.VIEW_TREASURY,
    Permissions.MANAGE_TREASURY,
    Permissions.MANAGE_BUSINESS,
})

local recruiter = PermissionSet({
    Permissions.INVITE_MEMBER,
    Permissions.KICK_MEMBER,
})

local treasury = PermissionSet({
    Permissions.VIEW_TREASURY,
    Permissions.MANAGE_TREASURY,
})

local function Rank(name, label, weight, permissions, salary, color, icon)
    return {
        Name = name,
        Label = label,
        Weight = weight,
        Permissions = permissions or {},
        Salary = salary or 0,
        Color = color,
        Icon = icon,
    }
end

GS.OrganizationRankTemplates.Custom = {
    Label = "Custom",
    Ranks = {
        Rank("Leader", "Leader", 100, owner, 0, "#D4AF37", "crown"),
        Rank("Member", "Member", 50, {}, 0, "#6B7280", "user"),
        Rank("Recruit", "Recruit", 10, {}, 0, "#9CA3AF", "user-plus"),
    },
}

GS.OrganizationRankTemplates.Gang = {
    Label = "Gang",
    Ranks = {
        Rank("Leader", "Boss", 100, owner, 0, "#D4AF37", "crown"),
        Rank("Underboss", "Underboss", 85, manager, 0, "#7C3AED", "shield"),
        Rank("Enforcer", "Enforcer", 65, recruiter, 0, "#DC2626", "skull"),
        Rank("Member", "Soldier", 40, {}, 0, "#374151", "user"),
        Rank("Recruit", "Prospect", 10, {}, 0, "#9CA3AF", "user-plus"),
    },
}

GS.OrganizationRankTemplates.Cartel = {
    Label = "Cartel",
    Ranks = {
        Rank("Leader", "Jefe", 100, owner, 0, "#D4AF37", "crown"),
        Rank("Lieutenant", "Lieutenant", 80, manager, 0, "#B91C1C", "shield"),
        Rank("Distributor", "Distributor", 60, recruiter, 0, "#047857", "package"),
        Rank("Member", "Soldado", 40, {}, 0, "#374151", "user"),
        Rank("Recruit", "Runner", 10, {}, 0, "#9CA3AF", "user-plus"),
    },
}

GS.OrganizationRankTemplates.Mafia = {
    Label = "Mafia",
    Ranks = {
        Rank("Leader", "Don", 100, owner, 0, "#D4AF37", "crown"),
        Rank("Consigliere", "Consigliere", 90, manager, 0, "#4B5563", "briefcase"),
        Rank("Caporegime", "Caporegime", 75, recruiter, 0, "#111827", "shield"),
        Rank("Member", "Made Man", 50, {}, 0, "#374151", "user"),
        Rank("Recruit", "Associate", 10, {}, 0, "#9CA3AF", "user-plus"),
    },
}

GS.OrganizationRankTemplates.MotorcycleClub = {
    Label = "Motorcycle Club",
    Ranks = {
        Rank("Leader", "President", 100, owner, 0, "#D4AF37", "crown"),
        Rank("VicePresident", "Vice President", 90, manager, 0, "#1F2937", "shield"),
        Rank("SergeantAtArms", "Sergeant at Arms", 75, recruiter, 0, "#B91C1C", "wrench"),
        Rank("Member", "Patch Member", 50, {}, 0, "#374151", "user"),
        Rank("Recruit", "Prospect", 10, {}, 0, "#9CA3AF", "user-plus"),
    },
}

GS.OrganizationRankTemplates.Police = {
    Label = "Police",
    Ranks = {
        Rank("Leader", "Chief", 100, owner, 2500, "#1D4ED8", "shield"),
        Rank("Captain", "Captain", 85, manager, 2000, "#2563EB", "badge"),
        Rank("Lieutenant", "Lieutenant", 70, recruiter, 1750, "#3B82F6", "badge"),
        Rank("Officer", "Officer", 50, {}, 1250, "#60A5FA", "user"),
        Rank("Recruit", "Cadet", 10, {}, 750, "#93C5FD", "user-plus"),
    },
}

GS.OrganizationRankTemplates.Government = {
    Label = "Government",
    Ranks = {
        Rank("Leader", "Director", 100, owner, 3000, "#D4AF37", "landmark"),
        Rank("DeputyDirector", "Deputy Director", 85, manager, 2400, "#4B5563", "briefcase"),
        Rank("Administrator", "Administrator", 65, treasury, 1800, "#6B7280", "clipboard"),
        Rank("Member", "Staff", 40, {}, 1200, "#9CA3AF", "user"),
        Rank("Recruit", "Intern", 10, {}, 500, "#D1D5DB", "user-plus"),
    },
}

GS.OrganizationRankTemplates.Business = {
    Label = "Business",
    Ranks = {
        Rank("Leader", "Owner", 100, owner, 0, "#D4AF37", "briefcase"),
        Rank("Manager", "Manager", 80, manager, 1800, "#059669", "clipboard"),
        Rank("Supervisor", "Supervisor", 60, recruiter, 1400, "#10B981", "users"),
        Rank("Member", "Employee", 40, {}, 900, "#34D399", "user"),
        Rank("Recruit", "Trainee", 10, {}, 400, "#A7F3D0", "user-plus"),
    },
}

GS.OrganizationRankTemplates.Security = {
    Label = "Security",
    Ranks = {
        Rank("Leader", "Commander", 100, owner, 2200, "#D4AF37", "shield"),
        Rank("OperationsLead", "Operations Lead", 80, manager, 1800, "#374151", "clipboard"),
        Rank("SeniorAgent", "Senior Agent", 60, recruiter, 1400, "#4B5563", "user-check"),
        Rank("Member", "Agent", 40, {}, 1000, "#6B7280", "user"),
        Rank("Recruit", "Trainee", 10, {}, 500, "#9CA3AF", "user-plus"),
    },
}

GS.OrganizationRankTemplates.EMS = {
    Label = "EMS",
    Ranks = {
        Rank("Leader", "Medical Director", 100, owner, 2400, "#DC2626", "heart-pulse"),
        Rank("Doctor", "Doctor", 85, manager, 2000, "#EF4444", "stethoscope"),
        Rank("ParamedicLead", "Paramedic Lead", 65, recruiter, 1600, "#F87171", "clipboard"),
        Rank("Member", "Paramedic", 40, {}, 1100, "#FCA5A5", "user"),
        Rank("Recruit", "EMT Trainee", 10, {}, 600, "#FECACA", "user-plus"),
    },
}

