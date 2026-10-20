import bpy, math, random, os
from mathutils import Vector
root=os.path.join(os.path.dirname(os.path.dirname(__file__)),'assets','models')
random.seed(88)
def mat(name,color):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*color,1)
    m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.88
    return m
def mesh(name,verts,faces,material,parent=None):
    m=bpy.data.meshes.new(name); m.from_pydata(verts,[],faces); m.update()
    o=bpy.data.objects.new(name,m); bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    if parent:o.parent=parent
    return o
def empty(name,pos,parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=pos
    if parent:o.parent=parent
    return o
def rings(name,spec,material,n=10,parent=None):
    v=[]
    for z,rx,ry,cx,cy in spec:
        for i in range(n):
            a=2*math.pi*i/n;v.append((cx+rx*math.cos(a),cy+ry*math.sin(a),z))
    f=[tuple(range(n-1,-1,-1))]
    for j in range(len(spec)-1):
        for i in range(n):
            a=j*n+i;b=j*n+(i+1)%n;c=b+n;d=a+n
            f.append((a,b,c,d))
    f.append(tuple(range((len(spec)-1)*n,len(v))))
    return mesh(name,v,f,material,parent)
def ball(name,pos,scale,material,parent=None,segments=12,rings_count=7):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings_count,location=pos)
    o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(material)
    if parent:o.parent=parent
    return o
def bar(name,a,b,r,material,parent=None,verts=8):
    a,b=Vector(a),Vector(b);d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=d.length,location=(a+b)/2)
    o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(material)
    if parent:o.parent=parent
    return o
def character(kind):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    skin=mat('Pele',(.58,.37,.25) if kind=='vito' else (.7,.49,.34))
    dark=mat('Cabelo',(.035,.026,.035) if kind!='ex' else (.21,.065,.035))
    black=mat('Armação',(.025,.025,.035));white=mat('Olhos',(.84,.83,.72))
    shirt=mat('Roupa',{'vito':(.035,.045,.07),'douglas':(.84,.89,.85),'rival':(.33,.14,.48),'ex':(.68,.12,.19),'npc':(.08,.39,.35),'driver':(.64,.43,.16)}[kind])
    pants=mat('Calça',(.07,.095,.15) if kind!='ex' else (.13,.15,.24))
    shoes=mat('Tênis',(.1,.10,.13));sole=mat('Sola',(.68,.65,.59))
    rootnode=empty('Body',(0,0,0))
    rings('Torso',[(.88,.21,.13,0,0),(1.02,.24,.15,0,0),(1.32,.29,.17,0,0),(1.45,.27,.14,0,0),(1.49,.14,.12,0,0)],shirt,12,rootnode)
    rings('Barra',[(.87,.22,.14,0,0),(.91,.22,.14,0,0)],shirt,12,rootnode)
    rings('Neck',[(1.42,.085,.085,0,0),(1.59,.085,.085,0,0)],skin,10,rootnode)
    head=empty('Head',(0,0,1.62),rootnode)
    rings('Face',[(-.12,.095,.10,0,-.012),(-.07,.14,.115,0,-.018),(.07,.16,.13,0,0),(.22,.145,.12,0,.01),(.27,.10,.09,0,.01)],skin,12,head)
    ball('Nose',(0,-.133,.045),(.037,.05,.04),skin,head)
    for s in [-1,1]:
        ball('Ear',(s*.16,0,.035),(.036,.027,.058),skin,head,8,5)
        ball('Eye',(s*.066,-.117,.078),(.043,.018,.021),white,head,8,5)
        ball('Pupil',(s*.066,-.135,.078),(.014,.008,.015),black,head,8,5)
        bar('Brow',(s*.035,-.14,.113),(s*.103,-.127,.116),.009,dark,head)
    bar('Mouth',(-.039,-.117,-.059),(.039,-.117,-.059),.006,dark,head)
    if kind in ('vito','driver'):
        beard=mat('Barba',(.12,.075,.06))
        rings('Beard',[(-.125,.097,.102,0,-.015),(-.085,.139,.118,0,-.018),(-.035,.145,.116,0,-.01)],beard,12,head)
        bar('Moustache',(-.047,-.137,-.03),(.047,-.137,-.03),.011,beard,head)
        for s in [-1,1]:
            cx=s*.076
            pts=[(cx+math.cos(i*math.tau/6)*.068,-.155,.073+math.sin(i*math.tau/6)*.049) for i in range(6)]
            for i in range(6):bar('Glasses',pts[i],pts[(i+1)%6],.006,black,head,6)
            bar('GlassesSide',(s*.14,-.15,.09),(s*.16,.035,.085),.005,black,head)
        bar('GlassesBridge',(-.012,-.16,.077),(.012,-.16,.077),.006,black,head)
    rings('Hair',[ (.10,.163,.132,0,.032),(.22,.17,.14,0,.018),(.31,.125,.105,-.018,.013),(.34,.055,.055,-.01,.01)],dark,10,head)
    ball('Fringe',(-.055,-.09,.215),(.13,.09,.085),dark,head,9,5)
    if kind=='ex':
        ball('LongHair',(0,.10,-.05),(.19,.10,.32),dark,head,10,6)
    for s in [-1,1]:
        arm=empty('ArmL' if s<0 else 'ArmR',(s*.29,0,1.37),rootnode)
        rings('Sleeve',[(.05,.105,.12,0,0),(-.19,.104,.11,s*.02,0)],shirt,8,arm)
        rings('Arm', [(-.14,.078,.078,s*.02,0),(-.34,.07,.071,s*.048,-.01),(-.54,.05,.055,s*.048,-.035)],skin,8,arm)
        ball('Hand',(s*.048,-.04,-.57),(.061,.065,.085),skin,arm,8,5)
        leg=empty('LegL' if s<0 else 'LegR',(s*.12,0,.91),rootnode)
        rings('Leg',[(0,.105,.125,0,0),(-.32,.087,.09,0,0),(-.7,.068,.075,0,.005)],pants,8,leg)
        ball('Shoe',(0,-.055,-.77),(.088,.16,.085),shoes,leg,10,5)
        ball('Sole',(0,-.055,-.822),(.09,.16,.025),sole,leg,10,4)
    if kind=='vito':
        patch=mat('Estampa',(.19,.15,.24))
        mesh('ShirtPrint',[(-.14,-.164,1.16),(.14,-.164,1.16),(.14,-.17,1.29),(-.14,-.17,1.29)],[(0,1,2,3)],patch,rootnode)
    if kind=='douglas':
        teal=mat('Medico',(.06,.36,.37))
        bar('Gravata',(0,-.168,1.38),(0,-.168,1.09),.028,teal,rootnode,4)
        for s in [-1,1]:bar('Estetoscopio',(s*.1,-.175,1.4),(s*.1,-.18,1.16),.009,black,rootnode)
        ball('EstetoscopioDisco',(.1,-.19,1.12),(.034,.012,.034),sole,rootnode)
    bpy.ops.export_scene.gltf(filepath=os.path.join(root,kind+'.glb'),export_format='GLB',export_yup=True)
for k in ['vito','douglas','rival','ex','npc','driver']:character(k)
print('MODELS_OK')
