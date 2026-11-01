/* omt_dump: port of tools/omt/omtdump.cpp (neutron2 branch gltf-export) as a library call: collects shapes, materials and
   the textures' PNG bytes in memory instead of writing the .odmp text file. */
#include "omt_dump.h"
#include "OMediaDataBase.h"
#include "OMediaFileStream.h"
#include "OMediaFilePath.h"
#include "OMediaCanvas.h"
#include "OMedia3DShape.h"
#include "OMedia3DMaterial.h"
#include "OMedia3DPolygon.h"
#include "OMediaError.h"
#include <stdio.h>
#include <stdlib.h>
#include <set>

using std::string;

/* The offline converter went through omtdump's text output ("%g", 6 significant digits); the same rounding is applied here so the
   in-app import produces the same level geometry as the PC tools did (the game's cover / spawn layout was tuned on it). */
static float r6(float x) { char b[40]; snprintf(b, sizeof b, "%g", (double)x); return (float)atof(b); }

bool omt_dump(const string &omt_path, const string &tmp_dir, OdDump &out, string &err)
{
	OMediaDataBase::set_cache_size(0);
	omd_REGISTERCLASS(OMediaCanvas);
	omd_REGISTERCLASS(OMedia3DShape);
	omd_REGISTERCLASS(OMedia3DMaterial);
	try
	{
		OMediaFilePath path(omt_path);
		OMediaFileStream f; f.setpath(&path); f.open(omcfp_Read);
		OMediaDataBase *db = new OMediaDataBase(&f);
		omt_DBIterator it;
		std::map<OMedia3DMaterial*, int> mats;
		std::vector<OMedia3DMaterial*> matlist;
		std::vector<OMedia3DShape*> shapes;
		for (OMediaDBObject *x = db->get_first_object(OMedia3DShape::db_type, it); x; x = db->get_next_object(it))
		{
			OMedia3DShape *s = (OMedia3DShape*)x; s->db_lock(); shapes.push_back(s);
			omt_PolygonList *pl = s->get_polygons();
			for (omt_PolygonList::iterator p = pl->begin(); p != pl->end(); p++)
			{
				OMedia3DMaterial *m = (*p).get_material();
				if (m && !mats.count(m)) { mats[m] = (int)matlist.size(); matlist.push_back(m); }
			}
		}
		std::set<int> texids;
		string tmpfile = tmp_dir + "/omt_tex.png";
		for (size_t i = 0; i < matlist.size(); i++)
		{
			OMedia3DMaterial *m = matlist[i];
			OMediaFARGBColor d, e; m->get_diffuse(d); m->get_emission(e);
			string mn; m->get_chunk_name(mn);
			OMediaCanvas *t = m->get_texture();
			OdMaterial om; om.tex = -1;
			if (t)
			{
				int tid = (int)t->get_chunk_ID();
				om.tex = tid;
				if (!texids.count(tid))
				{
					texids.insert(tid);
					t->db_lock(); t->lock(omlf_Read);
					if (t->get_width() > 0 && t->get_height() > 0)
					{
						{ OMediaFilePath op(tmpfile); OMediaFileStream os; os.setpath(&op); os.open(omcfp_Write, true);
						  t->png_export(os); os.close(); }
						FILE *pf = fopen(tmpfile.c_str(), "rb");
						if (pf)
						{
							std::vector<unsigned char> b; unsigned char buf[65536]; size_t n;
							while ((n = fread(buf, 1, sizeof buf, pf)) > 0) b.insert(b.end(), buf, buf + n);
							fclose(pf); remove(tmpfile.c_str());
							out.png[tid] = b;
						}
					}
					t->unlock();
				}
			}
			om.diffuse[0] = d.red; om.diffuse[1] = d.green; om.diffuse[2] = d.blue; om.diffuse[3] = d.alpha;
			om.flags = (int)m->get_flags(); om.name = mn.empty() ? string("-") : mn;
			out.mats.push_back(om);
		}
		for (size_t si = 0; si < shapes.size(); si++)
		{
			OMedia3DShape *s = shapes[si];
			OdShape os;
			s->get_chunk_name(os.name);
			if (os.name.empty()) os.name = "shape";
			for (size_t i = 0; i < os.name.size(); i++) if (os.name[i] <= ' ') os.name[i] = '_';
			omt_VertexList *vl = s->get_vertices(); omt_PolygonList *pl = s->get_polygons();
			for (omt_VertexList::iterator v = vl->begin(); v != vl->end(); v++)
			{ os.v.push_back(r6((*v).x)); os.v.push_back(r6((*v).y)); os.v.push_back(r6((*v).z)); }
			for (omt_PolygonList::iterator p = pl->begin(); p != pl->end(); p++)
			{
				OMedia3DMaterial *m = (*p).get_material();
				omt_3DPolygonVertexList &pv = (*p).get_vertices();
				OdPoly op; op.mat = m ? mats[m] : -1; op.flags = (int)(*p).get_flags();
				for (omt_3DPolygonVertexList::iterator q = pv.begin(); q != pv.end(); q++)
				{ op.vi.push_back((*q).vertex_index); op.uv.push_back(r6((*q).u)); op.uv.push_back(r6((*q).v)); }
				os.polys.push_back(op);
			}
			out.shapes.push_back(os);
		}
		for (size_t si = 0; si < shapes.size(); si++) shapes[si]->db_unlock();
		delete db;
	}
	catch (OMediaError &e)
	{
		char b[128]; snprintf(b, sizeof b, "cannot read %s (OMT error %d)", omt_path.c_str(), (int)e.errorcode);
		err = b; return false;
	}
	return true;
}
